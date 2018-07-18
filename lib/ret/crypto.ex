defmodule Ret.Crypto do
  @header_bytes <<184, 165, 211, 58, 11, 5, 200, 155>>
  @chunk_size 32 * 1024

  # Takes the file at source path and stream encrypts it using AES-CTR
  # to a file at dest path. The file has a header that has a magic number
  # (to easily check if the decryption key is correct) as well as the
  # original file length.
  def encrypt_file(source_path, key, dest_path) do
    case File.stat(source_path) do
      {:ok, %{size: source_size}} ->
        outfile = File.stream!(dest_path, [], @chunk_size)
        infile = source_path |> File.stream!([], @chunk_size)

        state = :crypto.stream_init(:aes_ctr, :crypto.hash(:sha256, key), <<0::size(128)>>)

        Stream.concat([@header_bytes, <<source_size::size(32)>>], infile)
        |> Stream.flat_map(&:binary.bin_to_list/1)
        |> Stream.chunk_every(@chunk_size)
        |> Stream.map(&pad_chunk/1)
        |> Stream.scan({state, nil}, &encrypt_chunk/2)
        |> Stream.map(fn x -> elem(x, 1) end)
        |> Enum.into(outfile)

        {:ok, outfile}

      {:error, _reason} = err ->
        err
    end
  end

  def stream_decrypt_file(source_path, key) do
    infile = source_path |> File.stream!([], @chunk_size)
    state = :crypto.stream_init(:aes_ctr, :crypto.hash(:sha256, key), <<0::size(128)>>)

    [<<header_ciphertext::binary-size(12), header_chunk::binary>>] =
      infile |> Stream.take(1) |> Enum.map(& &1)

    case :crypto.stream_decrypt(state, header_ciphertext) do
      {_state, <<@header_bytes, file_size::size(32)>>} ->
        state = :crypto.stream_init(:aes_ctr, :crypto.hash(:sha256, key), <<0::size(128)>>)

        infile
        |> Stream.flat_map(&:binary.bin_to_list/1)
        |> Stream.chunk_every(@chunk_size)
        |> Stream.scan({nil, file_size, state, nil}, &decrypt_chunk/2)
        |> Stream.map(fn x -> elem(x, 3) end)

      _ ->
        {:error, :invalid_key}
    end
  end

  defp pad_chunk(chunk) when length(chunk) == @chunk_size, do: chunk

  defp pad_chunk(chunk) do
    rem = @chunk_size - length(chunk)
    zeros = List.duplicate(0, rem)
    Enum.concat([chunk, zeros])
  end

  defp encrypt_chunk(chunk, {state, _ciphertext}) do
    :crypto.stream_encrypt(state, chunk)
  end

  # At beginning, skip header
  defp decrypt_chunk(ciphertext, {nil, total_bytes, state, _plaintext}) do
    {state, <<_header::binary-size(12), body::binary>>} =
      :crypto.stream_decrypt(state, ciphertext)

    {String.length(body), total_bytes, state, body}
  end

  defp decrypt_chunk(ciphertext, {decrypted_bytes, total_bytes, state, _plaintext}) do
    max_bytes = min(total_bytes - decrypted_bytes, @chunk_size)

    {state, <<plaintext::binary-size(max_bytes), _padding::binary>>} =
      :crypto.stream_decrypt(state, ciphertext)

    {decrypted_bytes + String.length(plaintext), total_bytes, state, plaintext}
  end
end
