defmodule Ret.Crypto do
  @aad "AES256GCM"
  @aead_cipher :aes_256_gcm
  @chunk_size 1024 * 1024
  @header_bytes <<184, 165, 211, 58, 11, 5, 200, 155>>
  @iv <<0::size(128)>>
  @iv_cipher :aes_256_ctr
  @min_aes_size 12

  # Takes a stream and encrypts it using AES-CTR to a file at dest path.
  # The file has a header that has a magic number
  # (to easily check if the decryption key is correct) as well as the
  # original file length.
  def encrypt_stream_to_file(source_stream, source_size, destination_path, key) do
    outfile = File.stream!(destination_path, [], @chunk_size)
    state = crypto_stream(:encrypt, crypto_hash(key))

    [@header_bytes <> <<source_size::size(32)>>]
    |> Stream.concat(source_stream)
    |> Stream.map(&pad_chunk/1)
    |> Stream.scan({state, nil}, &encrypt_chunk/2)
    |> Stream.map(fn x -> elem(x, 1) end)
    |> Enum.into(outfile)
  end

  def encrypt(plaintext, key \\ default_secret_key()) do
    one_time_iv = :crypto.strong_rand_bytes(16)
    hashed_key = crypto_hash(key)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(
        @aead_cipher,
        hashed_key,
        one_time_iv,
        to_string(plaintext),
        @aad,
        16,
        true
      )

    one_time_iv <> tag <> ciphertext
  end

  def decrypt(ciphertext, key \\ default_secret_key()) do
    <<one_time_iv::binary-16, tag::binary-16, ciphertext::binary>> = ciphertext
    hashed_key = crypto_hash(key)

    :crypto.crypto_one_time_aead(
      @aead_cipher,
      hashed_key,
      one_time_iv,
      ciphertext,
      @aad,
      tag,
      false
    )
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
        state = crypto_stream(:decrypt, aes_key)

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
    aes_key = crypto_hash(key)
    state = crypto_stream(:decrypt, aes_key)

    [<<header_ciphertext::binary-size(12), _header_chunk::binary>>] =
      infile |> Stream.take(1) |> Enum.map(& &1)

    case :crypto.crypto_update(state, header_ciphertext) do
      <<@header_bytes, file_size::size(32)>> ->
        {:ok, file_size, aes_key, infile}

      _ ->
        {:error, :invalid_key}
    end
  end

  def hash(plaintext, key \\ default_secret_key()) do
    (plaintext <> crypto_hash(plaintext <> key))
    |> crypto_hash()
    |> :base64.encode()
  end

  @spec crypto_hash(String.t()) :: <<_::256>>
  defp crypto_hash(key) when is_binary(key),
    do: :crypto.hash(:sha256, key)

  @spec crypto_stream(:encrypt | :decrypt, <<_::256>>) :: :crypto.crypto_state()
  defp crypto_stream(action, <<_::256>> = aes_key) when action in [:encrypt, :decrypt],
    do: :crypto.crypto_init(@iv_cipher, aes_key, @iv, action === :encrypt)

  defp pad_chunk(chunk) when byte_size(chunk) >= @min_aes_size, do: chunk

  defp pad_chunk(chunk) do
    rem = @min_aes_size - byte_size(chunk)
    zeros_size = rem * 8
    zeros = <<0::size(zeros_size)>>
    chunk <> zeros
  end

  defp encrypt_chunk(chunk, {state, _ciphertext}) do
    result = :crypto.crypto_update(state, chunk)
    {state, result}
  end

  # At beginning, skip header
  defp decrypt_chunk(ciphertext, {nil, total_bytes, state, _plaintext})
       when total_bytes < @min_aes_size do
    max_bytes = min(total_bytes, @min_aes_size)

    <<_header::binary-size(12), body::binary-size(max_bytes), _padding::binary>> =
      :crypto.crypto_update(state, ciphertext)

    {byte_size(body), total_bytes, state, body}
  end

  # At beginning, skip header
  defp decrypt_chunk(ciphertext, {nil, total_bytes, state, _plaintext}) do
    <<_header::binary-size(12), body::binary>> = :crypto.crypto_update(state, ciphertext)
    {byte_size(body), total_bytes, state, body}
  end

  defp decrypt_chunk(ciphertext, {decrypted_bytes, total_bytes, state, _plaintext}) do
    max_bytes = min(total_bytes - decrypted_bytes, byte_size(ciphertext))

    <<plaintext::binary-size(max_bytes), _padding::binary>> =
      :crypto.crypto_update(state, ciphertext)

    {decrypted_bytes + byte_size(plaintext), total_bytes, state, plaintext}
  end

  defp default_secret_key(), do: Application.get_env(:ret, RetWeb.Endpoint)[:secret_key_base]
end
