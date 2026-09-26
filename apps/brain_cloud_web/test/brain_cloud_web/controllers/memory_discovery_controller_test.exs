defmodule BrainCloudWeb.MemoryDiscoveryControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Agents
  alias BrainCloud.Memories
  alias BrainCloud.Memories.MemoryRevision
  alias BrainCloud.Projects
  alias BrainCloud.Repo
  alias BrainCloud.Teams

  setup %{identity: owner} do
    {:ok, project} = Projects.create_project(%{name: "Memory discovery"}, owner.auth_context)
    %{project: project}
  end

  test "returns the exact empty envelope", %{conn: conn, identity: owner, project: project} do
    assert %{"memories" => [], "next_cursor" => nil} ==
             conn
             |> authenticate(owner)
             |> get(list_path(project))
             |> json_response(200)
  end

  test "lists exact bounded summaries with stable cursors and no read audit", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    {:ok, first} = create_memory(project.id, "# First", "# First\nBody", owner)
    {:ok, second} = create_memory(project.id, "Second", "Second body", owner)
    foreign = BrainCloud.DataCase.identity_fixture()
    {:ok, foreign_project} = Projects.create_project(%{name: "Foreign"}, foreign.auth_context)
    {:ok, _foreign_memory} = create_memory(foreign_project.id, "Hidden", "Hidden", foreign)
    before_count = Repo.aggregate(AuditEvent, :count, :id)

    first_page =
      conn
      |> authenticate(owner)
      |> get(~p"/v1/projects/#{project.id}/memories?limit=1&ignored=value")

    assert get_resp_header(first_page, "cache-control") == ["no-store"]

    assert %{"memories" => [summary], "next_cursor" => cursor} =
             json_response(first_page, 200)

    assert summary["id"] == first.id
    assert is_binary(cursor)
    refute Map.has_key?(summary["revision"], "content")

    assert Map.keys(summary) |> Enum.sort() ==
             ~w(id inserted_at project_id revision updated_at)

    assert Map.keys(summary["revision"]) |> Enum.sort() ==
             ~w(actor_id actor_type content_hash content_type excerpt id inserted_at memory_id revision_number title)

    assert summary["revision"]["excerpt"] == "First Body"

    assert %{"memories" => [%{"id" => id}], "next_cursor" => nil} =
             conn
             |> recycle()
             |> authenticate(owner)
             |> get(~p"/v1/projects/#{project.id}/memories?limit=100&cursor=#{cursor}")
             |> json_response(200)

    assert id == second.id
    assert Repo.aggregate(AuditEvent, :count, :id) == before_count
  end

  test "authorizes the project before validating pagination", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    member = member_fixture(owner)
    raw_token = member_token(owner, member, ["memory.read"])

    assert %{"error" => %{"code" => "project_not_found", "details" => %{}}} =
             conn
             |> bearer(raw_token)
             |> get(~p"/v1/projects/#{project.id}/memories?limit=0&cursor=bad")
             |> json_response(404)

    no_scope = member_token(owner, member, ["projects.read"])

    assert %{"error" => %{"code" => "forbidden", "details" => %{}}} =
             conn
             |> bearer(no_scope)
             |> get(~p"/v1/projects/not-a-uuid/memories?limit=0&cursor=bad")
             |> json_response(403)
  end

  test "returns deterministic combined pagination validation errors", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    assert %{
             "error" => %{
               "code" => "validation_failed",
               "message" => "Request validation failed",
               "details" => %{
                 "limit" => ["must be an integer between 1 and 100"],
                 "cursor" => ["is invalid"]
               }
             }
           } =
             conn
             |> authenticate(owner)
             |> get(~p"/v1/projects/#{project.id}/memories?limit=0&cursor=bad")
             |> json_response(422)

    oversized = String.duplicate("a", 513)

    assert %{"error" => %{"details" => %{"cursor" => ["is invalid"]}}} =
             conn
             |> recycle()
             |> authenticate(owner)
             |> get(~p"/v1/projects/#{project.id}/memories?cursor=#{oversized}")
             |> json_response(422)

    assert %{
             "error" => %{
               "details" => %{
                 "limit" => ["must be an integer between 1 and 100"],
                 "cursor" => ["is invalid"]
               }
             }
           } =
             conn
             |> recycle()
             |> authenticate(owner)
             |> get("/v1/projects/#{project.id}/memories?limit[value]=1&cursor[]=x")
             |> json_response(422)

    for query <- ["limit=", "cursor=", "cursor=#{String.duplicate("a", 512)}"] do
      assert %{"error" => %{"code" => "validation_failed"}} =
               conn
               |> recycle()
               |> authenticate(owner)
               |> get("/v1/projects/#{project.id}/memories?#{query}")
               |> json_response(422)
    end
  end

  test "projects only the latest revision without returning content", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    {:ok, memory} = create_memory(project.id, "Revision one", "First", owner)
    latest_content = "# Revision two\nLatest"

    latest =
      %MemoryRevision{}
      |> Ecto.Changeset.change(%{
        memory_id: memory.id,
        revision_number: 2,
        title: "Revision two",
        content: latest_content,
        content_type: "text/markdown",
        content_hash: Base.encode16(:crypto.hash(:sha256, latest_content), case: :lower),
        actor_user_id: owner.user.id
      })
      |> Repo.insert!()

    assert %{"memories" => [%{"revision" => revision}]} =
             conn
             |> authenticate(owner)
             |> get(list_path(project))
             |> json_response(200)

    assert revision["id"] == latest.id
    assert revision["revision_number"] == 2
    assert revision["excerpt"] == "Revision two Latest"
    refute Map.has_key?(revision, "content")
  end

  test "applies direct and active-team membership access without duplicate rows", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    {:ok, memory} = create_memory(project.id, "Shared", "Shared body", owner)
    member = member_fixture(owner)
    raw_token = member_token(owner, member, ["memory.read"])
    {:ok, team} = Teams.create_team(%{name: "Readers"}, owner.auth_context)
    {:ok, _} = Teams.put_team_membership(team.id, member.id, owner.auth_context)

    {:ok, _} =
      Projects.put_project_access_grant(project.id, member.id, "reader", owner.auth_context)

    {:ok, _} =
      Projects.put_team_project_access_grant(project.id, team.id, "reader", owner.auth_context)

    assert %{"memories" => [%{"id" => id}], "next_cursor" => nil} =
             conn |> bearer(raw_token) |> get(list_path(project)) |> json_response(200)

    assert id == memory.id

    :ok = Projects.delete_project_access_grant(project.id, member.id, owner.auth_context)

    assert %{"memories" => [%{"id" => ^id}]} =
             conn
             |> recycle()
             |> bearer(raw_token)
             |> get(list_path(project))
             |> json_response(200)

    {:ok, _} = Teams.deactivate_team(team.id, owner.auth_context)

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> recycle()
             |> bearer(raw_token)
             |> get(list_path(project))
             |> json_response(404)
  end

  test "applies direct agent access and revocation on the next request", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    {:ok, memory} = create_memory(project.id, "Agent", "Agent body", owner)
    {:ok, agent} = Agents.create_agent(%{name: "Reader"}, owner.auth_context)

    {:ok, _token, raw_token} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Memory discovery", scopes: ["memory.read"]},
        owner.auth_context
      )

    {:ok, _} =
      Projects.put_agent_project_access_grant(project.id, agent.id, "reader", owner.auth_context)

    assert %{"memories" => [%{"id" => id}]} =
             conn |> bearer(raw_token) |> get(list_path(project)) |> json_response(200)

    assert id == memory.id

    :ok = Projects.delete_agent_project_access_grant(project.id, agent.id, owner.auth_context)

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> recycle()
             |> bearer(raw_token)
             |> get(list_path(project))
             |> json_response(404)
  end

  test "requires a valid bearer token and conceals foreign projects", %{
    conn: conn,
    identity: owner,
    project: project
  } do
    assert %{"error" => %{"code" => "unauthorized"}} =
             build_conn() |> get(list_path(project)) |> json_response(401)

    assert %{"error" => %{"code" => "unauthorized"}} =
             build_conn()
             |> init_test_session(%{browser_session_token: "cookie-only"})
             |> get(list_path(project))
             |> json_response(401)

    {:ok, token, revoked_raw} =
      Accounts.create_api_token(owner.auth_context, %{
        name: "Revoked memory reader",
        scopes: ["memory.read"]
      })

    {:ok, _} = Accounts.revoke_api_token(owner.auth_context, token.id)

    assert %{"error" => %{"code" => "unauthorized"}} =
             conn |> bearer(revoked_raw) |> get(list_path(project)) |> json_response(401)

    foreign = BrainCloud.DataCase.identity_fixture()

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> recycle()
             |> authenticate(foreign)
             |> get(list_path(project))
             |> json_response(404)
  end

  defp create_memory(project_id, title, content, owner) do
    Memories.create_memory(
      project_id,
      %{title: title, content: content, content_type: "text/markdown"},
      owner.auth_context
    )
  end

  defp member_fixture(owner) do
    suffix = Ecto.UUID.generate()

    {:ok, member} =
      Accounts.create_organization_membership(owner.auth_context, %{
        email: "memory-discovery-#{suffix}@example.test",
        display_name: "Memory discovery",
        role: "member"
      })

    member
  end

  defp member_token(owner, member, scopes) do
    {:ok, _token, raw_token} =
      Accounts.create_membership_api_token(owner.auth_context, member.id, %{
        name: "Memory discovery",
        scopes: scopes
      })

    raw_token
  end

  defp bearer(conn, raw_token), do: put_req_header(conn, "authorization", "Bearer #{raw_token}")
  defp list_path(project), do: "/v1/projects/#{project.id}/memories"
end
