defmodule BrainCloudWeb.ProjectDiscoveryControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuditEvent
  alias BrainCloud.Agents
  alias BrainCloud.Projects
  alias BrainCloud.Repo
  alias BrainCloud.Teams

  test "lists owner projects with stable cursors and exact public fields", %{
    conn: conn,
    identity: identity
  } do
    {:ok, first} = Projects.create_project(%{name: "First"}, identity.auth_context)
    {:ok, second} = Projects.create_project(%{name: "Second"}, identity.auth_context)
    other = BrainCloud.DataCase.identity_fixture()
    {:ok, _foreign} = Projects.create_project(%{name: "Foreign"}, other.auth_context)

    first_page =
      conn
      |> authenticate(identity)
      |> get(~p"/v1/projects?limit=1")

    assert get_resp_header(first_page, "cache-control") == ["no-store"]

    assert %{"projects" => [project], "next_cursor" => cursor} = json_response(first_page, 200)
    assert project["id"] == first.id
    assert is_binary(cursor)

    assert Map.keys(project) |> Enum.sort() ==
             ~w(creator_actor_id id inserted_at name organization_id updated_at)

    final_page =
      conn
      |> authenticate(identity)
      |> get(~p"/v1/projects?limit=100&cursor=#{cursor}")

    assert %{"projects" => [%{"id" => id}], "next_cursor" => nil} =
             json_response(final_page, 200)

    assert id == second.id
  end

  test "shows only accessible project details without read audits", %{
    conn: conn,
    identity: identity
  } do
    {:ok, project} = Projects.create_project(%{name: "Visible"}, identity.auth_context)
    before_count = Repo.aggregate(AuditEvent, :count, :id)

    response =
      conn
      |> authenticate(identity)
      |> get(~p"/v1/projects/#{project.id}")

    assert get_resp_header(response, "cache-control") == ["no-store"]
    assert %{"project" => %{"id" => id}} = json_response(response, 200)
    assert id == project.id
    assert Repo.aggregate(AuditEvent, :count, :id) == before_count

    assert %{"error" => %{"code" => "project_not_found", "details" => %{}}} =
             conn
             |> authenticate(identity)
             |> get(~p"/v1/projects/not-a-uuid")
             |> json_response(404)
  end

  test "requires bearer authentication and the explicit projects.read scope", %{
    conn: conn,
    identity: identity
  } do
    assert %{"error" => %{"code" => "unauthorized"}} =
             build_conn() |> get(~p"/v1/projects") |> json_response(401)

    {:ok, _token, raw_token} =
      Accounts.create_api_token(identity.auth_context, %{
        name: "Create only",
        scopes: ["projects.create"]
      })

    for path <- [~p"/v1/projects", ~p"/v1/projects/#{Ecto.UUID.generate()}"] do
      assert %{"error" => %{"code" => "forbidden", "details" => %{}}} =
               conn
               |> put_req_header("authorization", "Bearer #{raw_token}")
               |> get(path)
               |> json_response(403)
    end
  end

  test "returns deterministic combined pagination validation errors", %{
    conn: conn,
    identity: identity
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
             |> authenticate(identity)
             |> get(~p"/v1/projects?limit=0&cursor=bad")
             |> json_response(422)

    oversized = String.duplicate("a", 513)

    assert %{"error" => %{"details" => %{"cursor" => ["is invalid"]}}} =
             conn
             |> authenticate(identity)
             |> get(~p"/v1/projects?cursor=#{oversized}")
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
             |> authenticate(identity)
             |> get("/v1/projects?limit[value]=1&cursor[]=x")
             |> json_response(422)
  end

  test "applies direct, team, agent, and tenant access before serialization", %{
    conn: conn,
    identity: owner
  } do
    suffix = Ecto.UUID.generate()

    {:ok, member} =
      Accounts.create_organization_membership(owner.auth_context, %{
        email: "web-discovery-#{suffix}@example.test",
        display_name: "Web discovery",
        role: "member"
      })

    {:ok, _member_token, member_raw} =
      Accounts.create_membership_api_token(owner.auth_context, member.id, %{
        name: "Discovery",
        scopes: ["projects.read"]
      })

    {:ok, project} = Projects.create_project(%{name: "Shared"}, owner.auth_context)
    {:ok, team} = Teams.create_team(%{name: "Shared readers"}, owner.auth_context)
    {:ok, _} = Teams.put_team_membership(team.id, member.id, owner.auth_context)

    {:ok, _} =
      Projects.put_project_access_grant(project.id, member.id, "reader", owner.auth_context)

    {:ok, _} =
      Projects.put_team_project_access_grant(project.id, team.id, "reader", owner.auth_context)

    assert %{"projects" => [%{"id" => id}]} =
             conn
             |> bearer(member_raw)
             |> get(~p"/v1/projects")
             |> json_response(200)

    assert id == project.id

    {:ok, agent} = Agents.create_agent(%{name: "Web agent"}, owner.auth_context)

    {:ok, _agent_token, agent_raw} =
      Agents.create_agent_token(
        agent.id,
        %{name: "Discovery", scopes: ["projects.read"]},
        owner.auth_context
      )

    {:ok, _} =
      Projects.put_agent_project_access_grant(
        project.id,
        agent.id,
        "reader",
        owner.auth_context
      )

    assert %{"project" => %{"id" => id}} =
             conn
             |> bearer(agent_raw)
             |> get(~p"/v1/projects/#{project.id}")
             |> json_response(200)

    assert id == project.id

    foreign = BrainCloud.DataCase.identity_fixture()

    assert %{"error" => %{"code" => "project_not_found"}} =
             conn
             |> authenticate(foreign)
             |> get(~p"/v1/projects/#{project.id}")
             |> json_response(404)
  end

  defp bearer(conn, raw_token) do
    put_req_header(conn, "authorization", "Bearer #{raw_token}")
  end
end
