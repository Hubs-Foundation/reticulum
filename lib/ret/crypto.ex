defmodule Ret.Crypto do
  @chunk_size 12
  @header_bytes <<184, 165, 211, 58, 11, 5, 200, 155, 104, 184, 111, 109>>

  def encrypt_file(source_path, key, dest_path) do
    outfile = File.stream!(dest_path)
    infile = source_path |> File.stream!()

    state = :crypto.stream_init(:aes_ctr, :crypto.hash(:sha256, key), <<0::size(128)>>)

    Stream.concat([@header_bytes], infile)
    |> Stream.flat_map(&:binary.bin_to_list/1)
    |> Stream.chunk_every(@chunk_size)
    |> Stream.map(&pad_chunk/1)
    |> Stream.scan({state, nil}, &encrypt_chunk/2)
    |> Stream.map(fn x -> elem(x, 1) end)
    |> Enum.into(outfile)

    {:ok, outfile}
  end

  def stream_decrypt_file(source_path, key) do
    infile = source_path |> File.stream!()
    state = :crypto.stream_init(:aes_ctr, :crypto.hash(:sha256, key), <<0::size(128)>>)

    [<<header_ciphertext::binary-size(@chunk_size), header_chunk::binary>>] =
      infile |> Stream.take(1) |> Enum.map(& &1)

    expected_header = @header_bytes

    case :crypto.stream_decrypt(state, header_ciphertext) do
      {state, ^expected_header} -> :ok
      _ -> {:error, :invalid_key}
    end
  end

  defp pad_chunk(chunk) when length(chunk) == @chunk_size, do: chunk

  defp pad_chunk(chunk) do
    rem = @chunk_size - length(chunk)
    zeros = List.duplicate(0, rem)
    Enum.concat([chunk, zeros, [rem]])
  end

  defp encrypt_chunk(chunk, {state, _ciphertext}) do
    :crypto.stream_encrypt(state, chunk)
  end
end
