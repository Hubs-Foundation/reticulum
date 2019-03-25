defmodule RetWeb.Api.V1.ProjectFileView do
  use RetWeb, :view
  alias Ret.{ProjectFile, AccountFile, OwnedFile}

  defp render_project_file(project_file, account_file) do
    %{
      name: project_file.name,
      project_file_id: project_file |> ProjectFile.to_sid(),
      account_file_id: account_file |> AccountFile.to_sid(),
      file_url: project_file.project_file_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      content_type: project_file.project_file_owned_file.content_type,
      content_length: project_file.project_file_owned_file.content_length
    }
  end

  def render("show.json", %{project_file: project_file, account_file: account_file}) do
    Map.merge(
      %{ status: :ok },
      render_project_file(project_file, account_file)
    )
  end
end
