defmodule RetWeb.ContentType do
  def sanitize_content_type(content_type) do
    downcase_content_type = String.downcase(content_type)

    cond do
      # Covers content_types like text/html, application/xhtml+xml, etc.
      downcase_content_type |> String.contains?("html") -> "text/plain"
      # Covers content_types like text/javascript, application/ecmascript, text/jscript, etc.
      downcase_content_type |> String.contains?("script") -> "text/plain"
      true -> content_type
    end
  end

  def is_forbidden_content_type(nil), do: false

  def is_forbidden_content_type(content_type) do
    downcase_content_type = String.downcase(content_type)
    # We want to forbid content types like text/html, application/xhtml+xml,
    # text/javascript, text/jacript, application/ecmascript, "test/test, text/html", etc.
    ["html", "script"] |> Enum.any?(&(downcase_content_type |> String.contains?(&1)))
  end
end
