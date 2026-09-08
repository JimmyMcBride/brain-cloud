defmodule BrainCloudWeb.ProjectCursor do
  @moduledoc false

  @max_encoded_bytes 512
  @timestamp_pattern ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/

  def encode(project) do
    %{
      "v" => 1,
      "inserted_at" => Calendar.strftime(project.inserted_at, "%Y-%m-%dT%H:%M:%S.%fZ"),
      "id" => project.id
    }
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  def decode(value) when is_binary(value) and byte_size(value) in 1..@max_encoded_bytes do
    with {:ok, json} <- Base.url_decode64(value, padding: false),
         {:ok, payload} <- Jason.decode(json),
         %{"v" => 1, "inserted_at" => timestamp, "id" => id} <- payload,
         3 <- map_size(payload),
         true <- is_binary(timestamp) and Regex.match?(@timestamp_pattern, timestamp),
         {:ok, inserted_at, 0} <- DateTime.from_iso8601(timestamp),
         {:ok, canonical_id} <- Ecto.UUID.cast(id),
         true <- canonical_id == id do
      {:ok, {inserted_at, id}}
    else
      _invalid -> {:error, :invalid_cursor}
    end
  end

  def decode(_value), do: {:error, :invalid_cursor}
end
