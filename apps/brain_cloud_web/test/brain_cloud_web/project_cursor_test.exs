defmodule BrainCloudWeb.ProjectCursorTest do
  use ExUnit.Case, async: true

  alias BrainCloudWeb.ProjectCursor

  test "round trips the canonical v1 position" do
    project = %{
      id: "00000000-0000-0000-0000-000000000001",
      inserted_at: ~U[2026-09-08 01:02:03.123456Z]
    }

    encoded = ProjectCursor.encode(project)
    refute String.contains?(encoded, "=")
    assert {:ok, {project.inserted_at, project.id}} == ProjectCursor.decode(encoded)
  end

  test "rejects unsafe or non-canonical payloads" do
    invalid_payloads = [
      %{"v" => 2, "inserted_at" => "2026-09-08T01:02:03.123456Z", "id" => Ecto.UUID.generate()},
      %{
        "v" => 1,
        "inserted_at" => "2026-09-08T01:02:03Z",
        "id" => Ecto.UUID.generate()
      },
      %{
        "v" => 1,
        "inserted_at" => "2026-09-08T01:02:03.123456Z",
        "id" => String.upcase(Ecto.UUID.generate())
      },
      %{
        "v" => 1,
        "inserted_at" => "2026-09-08T01:02:03.123456Z",
        "id" => Ecto.UUID.generate(),
        "extra" => true
      }
    ]

    for payload <- invalid_payloads do
      encoded = payload |> Jason.encode!() |> Base.url_encode64(padding: false)
      assert {:error, :invalid_cursor} = ProjectCursor.decode(encoded)
    end

    assert {:error, :invalid_cursor} = ProjectCursor.decode("")
    assert {:error, :invalid_cursor} = ProjectCursor.decode(%{})
    assert {:error, :invalid_cursor} = ProjectCursor.decode(String.duplicate("a", 513))
  end
end
