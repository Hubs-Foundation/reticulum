defmodule Ret.Crypto do
  @header_bytes <<184, 165, 211, 58, 11, 5, 200, 155>>

  @chunk_size 1024 * 1024
  @min_aes_size 12

  # Takes a stream and encrypts it using AES-CTR to a file at dest path.
  # The file has a header that has a magic number
  # (to easily check if the decryption key is correct) as well as the
  # original file length.
  def encrypt_stream_to_file(source_stream, source_size, destination_path, key) do
    outfile = File.stream!(destination_path, [], @chunk_size)
    state = :crypto.stream_init(:aes_ctr, :crypto.hash(:sha256, key), <<0::size(128)>>)

    [@header_bytes <> <<source_size::size(32)>>]
    |> Stream.concat(source_stream)
    |> Stream.map(&pad_chunk/1)
    |> Stream.scan({state, nil}, &encrypt_chunk/2)
    |> Stream.map(fn x -> elem(x, 1) end)
    |> Enum.into(outfile)
  end

  def encrypt(plaintext, key \\ default_secret_key()) do
    iv = :crypto.strong_rand_bytes(16)
    hashed_key = :crypto.hash(:sha256, key)

    {ciphertext, tag} =
      :crypto.block_encrypt(:aes_gcm, hashed_key, iv, {"AES256GCM", plaintext |> to_string(), 16})

    iv <> tag <> ciphertext
  end

  def decrypt(ciphertext, key \\ default_secret_key()) do
    <<iv::binary-16, tag::binary-16, ciphertext::binary>> = ciphertext
    hashed_key = :crypto.hash(:sha256, key)
    :crypto.block_decrypt(:aes_gcm, hashed_key, iv, {"AES256GCM", ciphertext, tag})
  end

  # Given the source path and the user-specified decryption key, return
  # { :ok } if the key is valid otherwise a relevant error.
  def stream_check_key(source_path, key) do
    case stream_decode_encrypted_header(source_path, key) do
      {:ok, _, _, _} -> {:ok}
      result -> result
    end
  end

  # Given the source path and the user-specified decryption key, return
  # { :error, reason } if decryption fails, or return { :ok, stream }
  # where stream is a Stream of the decrypted file contents.
  def decrypt_file_to_stream(source_path, key) do
    case stream_decode_encrypted_header(source_path, key) do
      {:ok, file_size, aes_key, stream} ->
        state = :crypto.stream_init(:aes_ctr, aes_key, <<0::size(128)>>)

        {:ok,
         stream
         |> Stream.scan({nil, file_size, state, nil}, &decrypt_chunk/2)
         |> Stream.map(fn x -> elem(x, 3) end)}

      result ->
        result
    end
  end

  defp stream_decode_encrypted_header(source_path, key) do
    infile = source_path |> File.stream!([], @chunk_size)
    aes_key = :crypto.hash(:sha256, key)
    state = :crypto.stream_init(:aes_ctr, aes_key, <<0::size(128)>>)

    [<<header_ciphertext::binary-size(12), _header_chunk::binary>>] =
      infile |> Stream.take(1) |> Enum.map(& &1)

    case :crypto.stream_decrypt(state, header_ciphertext) do
      {_state, <<@header_bytes, file_size::size(32)>>} ->
        {:ok, file_size, aes_key, infile}

      _ ->
        {:error, :invalid_key}
    end
  end

  def hash(plaintext, key \\ default_secret_key()) do
    :crypto.hash(:sha256, plaintext <> :crypto.hash(:sha256, plaintext <> key))
    |> :base64.encode()
  end

  defp pad_chunk(chunk) when byte_size(chunk) >= @min_aes_size, do: chunk

  defp pad_chunk(chunk) do
    rem = @min_aes_size - byte_size(chunk)
    zeros_size = rem * 8
    zeros = <<0::size(zeros_size)>>
    chunk <> zeros
  end

  defp encrypt_chunk(chunk, {state, _ciphertext}) do
    :crypto.stream_encrypt(state, chunk)
  end

  # At beginning, skip header
  defp decrypt_chunk(ciphertext, {nil, total_bytes, state, _plaintext})
       when total_bytes < @min_aes_size do
    max_bytes = min(total_bytes, @min_aes_size)

    {state, <<_header::binary-size(12), body::binary-size(max_bytes), _padding::binary>>} =
      :crypto.stream_decrypt(state, ciphertext)

    {byte_size(body), total_bytes, state, body}
  end

  # At beginning, skip header
  defp decrypt_chunk(ciphertext, {nil, total_bytes, state, _plaintext}) do
    {state, <<_header::binary-size(12), body::binary>>} =
      :crypto.stream_decrypt(state, ciphertext)

    {byte_size(body), total_bytes, state, body}
  end

  defp decrypt_chunk(ciphertext, {decrypted_bytes, total_bytes, state, _plaintext}) do
    max_bytes = min(total_bytes - decrypted_bytes, byte_size(ciphertext))

    {state, <<plaintext::binary-size(max_bytes), _padding::binary>>} =
      :crypto.stream_decrypt(state, ciphertext)

    {decrypted_bytes + byte_size(plaintext), total_bytes, state, plaintext}
  end

  defp default_secret_key(), do: Application.get_env(:ret, RetWeb.Endpoint)[:secret_key_base]
end
