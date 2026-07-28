defmodule BrainCloudWeb.ProjectControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  test "requires the exact development bearer token", %{conn: conn} do
    expected = %{
      "error" => %{
        "code" => "unauthorized",
        "message" => "Authentication required",
        "details" => %{}
      }
    }

    assert conn
           |> post(~p"/v1/projects", %{name: "Research"})
           |> json_response(401) == expected

    assert conn
           |> put_req_header("authorization", "Bearer wrong")
           |> post(~p"/v1/projects", %{name: "Research"})
           |> json_response(401) == expected

    requests = [
      fn request_conn -> post(request_conn, ~p"/v1/projects", %{name: "Research"}) end,
      fn request_conn ->
        post(request_conn, ~p"/v1/projects/#{Ecto.UUID.generate()}/memories", %{})
      end,
      fn request_conn ->
        get(
          request_conn,
          ~p"/v1/projects/#{Ecto.UUID.generate()}/memories/#{Ecto.UUID.generate()}"
        )
      end,
      fn request_conn ->
        get(request_conn, ~p"/v1/projects/#{Ecto.UUID.generate()}/search?q=x")
      end
    ]

    Enum.each(requests, fn request ->
      assert request.(build_conn()) |> json_response(401) == expected

      assert build_conn()
             |> put_req_header("authorization", "Basic malformed")
             |> request.()
             |> json_response(401) == expected
    end)
  end

  test "creates a project with the configured actor", %{conn: conn} do
    response =
      conn
      |> authenticate()
      |> post(~p"/v1/projects", %{name: "  Research  "})
      |> json_response(201)

    assert %{
             "project" => %{
               "id" => project_id,
               "name" => "Research",
               "creator_actor_id" => "00000000-0000-0000-0000-000000000001",
               "inserted_at" => inserted_at,
               "updated_at" => updated_at
             }
           } = response

    assert {:ok, _uuid} = Ecto.UUID.cast(project_id)
    assert {:ok, _, _} = DateTime.from_iso8601(inserted_at)
    assert {:ok, _, _} = DateTime.from_iso8601(updated_at)
  end

  test "returns structured validation errors", %{conn: conn} do
    assert %{
             "error" => %{
               "code" => "validation_failed",
               "message" => "Request validation failed",
               "details" => %{"name" => [_message]}
             }
           } =
             conn
             |> authenticate()
             |> post(~p"/v1/projects", %{name: " "})
             |> json_response(422)
  end
end
