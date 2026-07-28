defmodule BrainCloudWeb.MemoryControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Projects

  @actor_id "00000000-0000-0000-0000-000000000001"

  setup do
    {:ok, project} = Projects.create_project(%{name: "Research"}, @actor_id)
    {:ok, other_project} = Projects.create_project(%{name: "Other"}, @actor_id)
    %{project: project, other_project: other_project}
  end

  test "creates, retrieves, and searches an exact immutable revision", %{
    conn: conn,
    project: project
  } do
    content = "# Durable\nPhoenix cloud memory"

    create_response =
      conn
      |> authenticate()
      |> post(~p"/v1/projects/#{project.id}/memories", %{
        title: "  Phoenix Notes  ",
        content: content,
        content_type: "text/markdown"
      })
      |> json_response(201)

    assert %{
             "memory" => %{
               "id" => memory_id,
               "project_id" => project_id,
               "revision" => %{
                 "id" => revision_id,
                 "memory_id" => revision_memory_id,
                 "revision_number" => 1,
                 "title" => "Phoenix Notes",
                 "content" => ^content,
                 "content_type" => "text/markdown",
                 "content_hash" => content_hash,
                 "actor_id" => @actor_id,
                 "inserted_at" => revision_inserted_at
               }
             }
           } = create_response

    assert project_id == project.id
    assert revision_memory_id == memory_id
    assert content_hash == Base.encode16(:crypto.hash(:sha256, content), case: :lower)
    assert {:ok, _, _} = DateTime.from_iso8601(revision_inserted_at)

    get_response =
      conn
      |> recycle()
      |> authenticate()
      |> get(~p"/v1/projects/#{project.id}/memories/#{memory_id}")
      |> json_response(200)

    assert get_response == create_response

    assert %{
             "results" => [
               %{
                 "memory_id" => ^memory_id,
                 "revision_id" => ^revision_id,
                 "revision_number" => 1,
                 "title" => "Phoenix Notes",
                 "content_type" => "text/markdown",
                 "content_hash" => ^content_hash,
                 "excerpt" => "Durable Phoenix cloud memory",
                 "rank" => rank,
                 "actor_id" => @actor_id,
                 "inserted_at" => ^revision_inserted_at
               }
             ]
           } =
             conn
             |> recycle()
             |> authenticate()
             |> get(~p"/v1/projects/#{project.id}/search?q=phoenix")
             |> json_response(200)

    assert is_float(rank)
  end

  test "keeps retrieval and search scoped to the requested project", %{
    conn: conn,
    project: project,
    other_project: other_project
  } do
    %{"memory" => %{"id" => memory_id}} =
      conn
      |> authenticate()
      |> post(~p"/v1/projects/#{project.id}/memories", %{
        title: "Private",
        content: "project-only keyword",
        content_type: "text/markdown"
      })
      |> json_response(201)

    assert %{
             "error" => %{
               "code" => "memory_not_found",
               "message" => "Memory not found",
               "details" => %{}
             }
           } =
             conn
             |> recycle()
             |> authenticate()
             |> get(~p"/v1/projects/#{other_project.id}/memories/#{memory_id}")
             |> json_response(404)

    assert %{"results" => []} =
             conn
             |> recycle()
             |> authenticate()
             |> get(~p"/v1/projects/#{other_project.id}/search?q=project-only")
             |> json_response(200)
  end

  test "returns exact missing-resource and validation errors", %{conn: conn, project: project} do
    missing_project_id = Ecto.UUID.generate()

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> authenticate()
             |> post(~p"/v1/projects/#{missing_project_id}/memories", %{
               title: "Title",
               content: "Body",
               content_type: "text/markdown"
             })
             |> json_response(404)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "message" => "Request validation failed",
               "details" => %{"content_type" => [_message]}
             }
           } =
             conn
             |> recycle()
             |> authenticate()
             |> post(~p"/v1/projects/#{project.id}/memories", %{
               title: "Title",
               content: "Body",
               content_type: "text/plain"
             })
             |> json_response(422)

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "details" => %{"q" => [_message]}
             }
           } =
             conn
             |> recycle()
             |> authenticate()
             |> get(~p"/v1/projects/#{project.id}/search?q=%20")
             |> json_response(422)
  end
end
