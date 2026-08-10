defmodule BrainCloudWeb.AgentControllerTest do
  use BrainCloudWeb.ConnCase, async: false

  alias BrainCloud.Accounts
  alias BrainCloud.Projects

  test "serves exact lifecycle, credential, and grant contracts", %{
    conn: conn,
    identity: identity
  } do
    {:ok, project} = Projects.create_project(%{name: "Agent API"}, identity.auth_context)

    assert %{"agent" => agent} =
             conn
             |> authenticate(identity)
             |> post(~p"/v1/organization/agents", %{name: " Retriever "})
             |> json_response(201)

    assert agent == %{
             "id" => agent["id"],
             "name" => "Retriever",
             "active" => true,
             "deactivated_at" => nil,
             "inserted_at" => agent["inserted_at"],
             "updated_at" => agent["updated_at"]
           }

    assert %{"token" => token} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/agents/#{agent["id"]}/tokens", %{
               name: "Reader",
               scopes: ["memory.read", "search.keyword"]
             })
             |> json_response(201)

    assert Map.keys(token) |> Enum.sort() ==
             ~w(bootstrap expires_at id inserted_at name revoked_at scopes token)

    assert token["bootstrap"] == false
    raw_token = token["token"]

    assert %{"tokens" => human_tokens} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/auth/tokens")
             |> json_response(200)

    refute Enum.any?(human_tokens, &(&1["id"] == token["id"]))

    assert %{"tokens" => [metadata]} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/organization/agents/#{agent["id"]}/tokens")
             |> json_response(200)

    assert Map.keys(metadata) |> Enum.sort() ==
             ~w(bootstrap expires_at id inserted_at name revoked_at scopes)

    refute Map.has_key?(metadata, "agent_id")
    refute Map.has_key?(metadata, "token")

    assert %{"agent_access_grant" => grant} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/agent-access/#{agent["id"]}", %{
               access: "reader"
             })
             |> json_response(200)

    assert Map.keys(grant) |> Enum.sort() ==
             ~w(access agent_id id inserted_at project_id updated_at)

    assert %{"agent_access_grants" => [listed_grant]} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/projects/#{project.id}/agent-access")
             |> json_response(200)

    assert listed_grant == grant

    assert %{"agents" => [listed_agent]} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> get(~p"/v1/organization/agents")
             |> json_response(200)

    assert listed_agent["id"] == agent["id"]

    assert conn
           |> recycle()
           |> authenticate(identity)
           |> delete(~p"/v1/organization/agents/#{agent["id"]}")
           |> response(204) == ""

    assert {:error, :unauthorized} = Accounts.authenticate(raw_token)

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/agents/#{agent["id"]}/tokens", %{
               name: "Blocked",
               scopes: ["memory.read"]
             })
             |> json_response(409)
           ) == "agent_inactive"

    assert %{"agent" => %{"active" => true}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/agents/#{agent["id"]}/reactivate")
             |> json_response(200)
  end

  test "agent reads granted memory and receives forbidden before write lookup", %{
    conn: conn,
    identity: identity
  } do
    {:ok, project} = Projects.create_project(%{name: "Agent Read"}, identity.auth_context)

    %{"memory" => %{"id" => memory_id}} =
      conn
      |> authenticate(identity)
      |> post(~p"/v1/projects/#{project.id}/memories", %{
        title: "Agent memory",
        content: "retrieval keyword",
        content_type: "text/markdown"
      })
      |> json_response(201)

    %{"agent" => %{"id" => agent_id}} =
      conn
      |> recycle()
      |> authenticate(identity)
      |> post(~p"/v1/organization/agents", %{name: "Read Agent"})
      |> json_response(201)

    %{"token" => %{"token" => raw}} =
      conn
      |> recycle()
      |> authenticate(identity)
      |> post(~p"/v1/organization/agents/#{agent_id}/tokens", %{
        name: "Read",
        scopes: ["memory.read", "search.keyword"]
      })
      |> json_response(201)

    conn
    |> recycle()
    |> authenticate(identity)
    |> put(~p"/v1/projects/#{project.id}/agent-access/#{agent_id}", %{access: "reader"})
    |> json_response(200)

    assert %{"memory" => %{"id" => ^memory_id}} =
             conn
             |> recycle()
             |> bearer(raw)
             |> get(~p"/v1/projects/#{project.id}/memories/#{memory_id}")
             |> json_response(200)

    assert %{"results" => [_]} =
             conn
             |> recycle()
             |> bearer(raw)
             |> get(~p"/v1/projects/#{project.id}/search?q=retrieval")
             |> json_response(200)

    %{"token" => %{"token" => read_only_raw}} =
      conn
      |> recycle()
      |> authenticate(identity)
      |> post(~p"/v1/organization/agents/#{agent_id}/tokens", %{
        name: "Read only",
        scopes: ["memory.read"]
      })
      |> json_response(201)

    assert error_code(
             conn
             |> recycle()
             |> bearer(read_only_raw)
             |> get(~p"/v1/projects/#{project.id}/search?q=retrieval")
             |> json_response(403)
           ) == "forbidden"

    assert error_code(
             conn
             |> recycle()
             |> bearer(raw)
             |> post("/v1/projects/not-a-uuid/memories", %{
               title: "Blocked",
               content: "Blocked",
               content_type: "text/markdown"
             })
             |> json_response(403)
           ) == "forbidden"
  end

  test "agent editor writes with exact provenance and independent route scopes", %{
    conn: conn,
    identity: identity
  } do
    {:ok, project} = Projects.create_project(%{name: "Agent Write"}, identity.auth_context)

    %{"agent" => %{"id" => agent_id}} =
      conn
      |> authenticate(identity)
      |> post(~p"/v1/organization/agents", %{name: "Write Agent"})
      |> json_response(201)

    %{"token" => %{"token" => write_raw}} =
      conn
      |> recycle()
      |> authenticate(identity)
      |> post(~p"/v1/organization/agents/#{agent_id}/tokens", %{
        name: "Write",
        scopes: ["memory.write"]
      })
      |> json_response(201)

    write = %{title: "Agent-authored", content: "agent provenance", content_type: "text/markdown"}

    assert error_code(
             conn
             |> recycle()
             |> bearer(write_raw)
             |> post(~p"/v1/projects/#{project.id}/memories", write)
             |> json_response(404)
           ) == "project_not_found"

    conn
    |> recycle()
    |> authenticate(identity)
    |> put(~p"/v1/projects/#{project.id}/agent-access/#{agent_id}", %{access: "reader"})
    |> json_response(200)

    assert error_code(
             conn
             |> recycle()
             |> bearer(write_raw)
             |> post(~p"/v1/projects/#{project.id}/memories", write)
             |> json_response(404)
           ) == "project_not_found"

    assert %{"agent_access_grant" => %{"access" => "editor"}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{project.id}/agent-access/#{agent_id}", %{access: "editor"})
             |> json_response(200)

    assert %{
             "memory" => %{
               "id" => memory_id,
               "revision" => %{
                 "actor_type" => "agent",
                 "actor_id" => ^agent_id,
                 "title" => "Agent-authored"
               }
             }
           } =
             conn
             |> recycle()
             |> bearer(write_raw)
             |> post(~p"/v1/projects/#{project.id}/memories", write)
             |> json_response(201)

    assert error_code(
             conn
             |> recycle()
             |> bearer(write_raw)
             |> get(~p"/v1/projects/#{project.id}/memories/#{memory_id}")
             |> json_response(403)
           ) == "forbidden"

    %{"token" => %{"token" => read_raw}} =
      conn
      |> recycle()
      |> authenticate(identity)
      |> post(~p"/v1/organization/agents/#{agent_id}/tokens", %{
        name: "Read",
        scopes: ["memory.read", "search.keyword"]
      })
      |> json_response(201)

    assert %{
             "memory" => %{
               "revision" => %{"actor_type" => "agent", "actor_id" => ^agent_id}
             }
           } =
             conn
             |> recycle()
             |> bearer(read_raw)
             |> get(~p"/v1/projects/#{project.id}/memories/#{memory_id}")
             |> json_response(200)

    assert %{
             "results" => [
               %{"actor_type" => "agent", "actor_id" => ^agent_id}
             ]
           } =
             conn
             |> recycle()
             |> bearer(read_raw)
             |> get(~p"/v1/projects/#{project.id}/search?q=provenance")
             |> json_response(200)
  end

  test "enforces management before lookup and project-first grant errors", %{
    conn: conn,
    identity: identity
  } do
    missing = Ecto.UUID.generate()

    {:ok, _token, limited_raw} =
      Accounts.create_api_token(identity.auth_context, %{
        name: "Limited",
        scopes: ["projects.create"]
      })

    assert error_code(
             conn
             |> bearer(limited_raw)
             |> get(~p"/v1/organization/agents/#{missing}/tokens")
             |> json_response(403)
           ) == "forbidden"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put("/v1/projects/not-a-uuid/agent-access/not-a-uuid", %{access: "reader"})
             |> json_response(404)
           ) == "project_not_found"

    assert error_code(
             conn
             |> recycle()
             |> authenticate(identity)
             |> put(~p"/v1/projects/#{missing}/agent-access/not-a-uuid", %{access: "reader"})
             |> json_response(404)
           ) == "project_not_found"
  end

  test "member credentials cannot receive agents.manage", %{
    conn: conn,
    identity: identity
  } do
    %{"membership" => membership} =
      conn
      |> authenticate(identity)
      |> post(~p"/v1/organization/memberships", %{
        email: "agent-member@example.com",
        display_name: "Agent Member",
        role: "member"
      })
      |> json_response(201)

    assert %{"error" => %{"code" => "validation_failed", "details" => details}} =
             conn
             |> recycle()
             |> authenticate(identity)
             |> post(~p"/v1/organization/memberships/#{membership["id"]}/tokens", %{
               name: "Invalid",
               scopes: ["agents.manage"]
             })
             |> json_response(422)

    assert details["scopes"] == ["cannot include management scopes for a member"]
  end

  defp bearer(conn, raw),
    do: put_req_header(conn, "authorization", "Bearer #{raw}")

  defp error_code(response), do: response["error"]["code"]
end
