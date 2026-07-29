defmodule BrainCloudWeb.MemoryControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Projects

  setup %{identity: identity} do
    {:ok, project} = Projects.create_project(%{name: "Research"}, identity.auth_context)
    {:ok, other_project} = Projects.create_project(%{name: "Other"}, identity.auth_context)
    %{project: project, other_project: other_project}
  end

  test "creates, retrieves, and searches an exact immutable revision", %{
    conn: conn,
    project: project,
    identity: identity
  } do
    content = "# Durable\nPhoenix cloud memory"

    create_response =
      conn
      |> authenticate(identity)
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
                 "actor_id" => actor_id,
                 "inserted_at" => revision_inserted_at
               }
             }
           } = create_response

    assert project_id == project.id
    assert actor_id == identity.user.id
    assert revision_memory_id == memory_id
    assert content_hash == Base.encode16(:crypto.hash(:sha256, content), case: :lower)
    assert {:ok, _, _} = DateTime.from_iso8601(revision_inserted_at)

    get_response =
      conn
      |> recycle()
      |> authenticate(identity)
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
                 "actor_id" => ^actor_id,
                 "inserted_at" => ^revision_inserted_at
               }
             ]
           } =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{project.id}/search?q=phoenix")
             |> json_response(200)

    assert is_float(rank)
  end

  test "keeps retrieval and search scoped to the requested project", %{
    conn: conn,
    project: project,
    other_project: other_project,
    identity: identity
  } do
    %{"memory" => %{"id" => memory_id}} =
      conn
      |> authenticate(identity)
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
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{other_project.id}/memories/#{memory_id}")
             |> json_response(404)

    assert %{"results" => []} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{other_project.id}/search?q=project-only")
             |> json_response(200)
  end

  test "returns exact missing-resource and validation errors", %{
    conn: conn,
    project: project,
    identity: identity
  } do
    missing_project_id = Ecto.UUID.generate()

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> authenticate(identity)
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
             |> authenticate(identity)
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
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{project.id}/search?q=%20")
             |> json_response(422)
  end

  test "conceals cross-organization projects", %{conn: conn, project: project} do
    other_identity = BrainCloud.DataCase.identity_fixture()

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> authenticate(other_identity)
             |> post(~p"/v1/projects/#{project.id}/memories", %{
               title: "Title",
               content: "Body",
               content_type: "text/markdown"
             })
             |> json_response(404)

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> recycle()
             |> authenticate(other_identity)
             |> get(~p"/v1/projects/#{project.id}/search?q=body")
             |> json_response(404)
  end

  test "combines fixed token scopes with reader and editor project grants", %{
    conn: conn,
    project: project,
    identity: identity
  } do
    {:ok, memory} =
      BrainCloud.Memories.create_memory(
        project.id,
        %{title: "Existing", content: "Project boundary", content_type: "text/markdown"},
        identity.auth_context
      )

    suffix = Ecto.UUID.generate()

    {:ok, membership} =
      Accounts.create_organization_membership(identity.auth_context, %{
        email: "project-reader-#{suffix}@example.test",
        display_name: "Project Reader",
        role: "member"
      })

    {:ok, _token, raw_token} =
      Accounts.create_membership_api_token(identity.auth_context, membership.id, %{
        name: "Project operations",
        scopes: ["memory.write", "memory.read", "search.keyword"]
      })

    denied_conn = put_req_header(conn, "authorization", "Bearer #{raw_token}")

    assert %{"error" => %{"code" => "project_not_found"}} =
             denied_conn
             |> get(~p"/v1/projects/#{project.id}/memories/not-a-uuid")
             |> json_response(404)

    assert {:ok, _grant} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "reader",
               identity.auth_context
             )

    assert %{"memory" => %{"id" => memory_id}} =
             denied_conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{raw_token}")
             |> get(~p"/v1/projects/#{project.id}/memories/#{memory.id}")
             |> json_response(200)

    assert memory_id == memory.id

    assert %{"results" => [_result]} =
             denied_conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{raw_token}")
             |> get(~p"/v1/projects/#{project.id}/search?q=boundary")
             |> json_response(200)

    assert %{"error" => %{"code" => "project_not_found"}} =
             denied_conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{raw_token}")
             |> post(~p"/v1/projects/#{project.id}/memories", %{
               title: "Reader denied",
               content: "Denied",
               content_type: "text/markdown"
             })
             |> json_response(404)

    assert {:ok, _grant} =
             Projects.put_project_access_grant(
               project.id,
               membership.id,
               "editor",
               identity.auth_context
             )

    assert %{"memory" => %{"revision" => %{"title" => "Editor allowed"}}} =
             denied_conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{raw_token}")
             |> post(~p"/v1/projects/#{project.id}/memories", %{
               title: "Editor allowed",
               content: "Allowed",
               content_type: "text/markdown"
             })
             |> json_response(201)

    {:ok, _token, read_only_raw} =
      Accounts.create_membership_api_token(identity.auth_context, membership.id, %{
        name: "Fixed-scope reader",
        scopes: ["memory.read"]
      })

    assert %{"error" => %{"code" => "forbidden"}} =
             denied_conn
             |> recycle()
             |> put_req_header("authorization", "Bearer #{read_only_raw}")
             |> post(~p"/v1/projects/#{project.id}/memories", %{
               title: "Scope denied",
               content: "Denied",
               content_type: "text/markdown"
             })
             |> json_response(403)
  end
end
