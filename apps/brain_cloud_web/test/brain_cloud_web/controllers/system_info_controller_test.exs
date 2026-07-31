defmodule BrainCloudWeb.SystemInfoControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  test "returns the public compatibility surface", %{conn: conn} do
    conn = get(conn, ~p"/v1/system/info")

    assert json_response(conn, 200) == %{
             "server" => "brain-cloud",
             "server_version" => "0.0.0-dev",
             "protocol_version" => "v1",
             "capabilities" => [
               "system.info",
               "projects.create",
               "projects.manage_access",
               "memory.write",
               "memory.read",
               "search.keyword",
               "members.manage",
               "teams.manage",
               "agents.manage",
               "tokens.manage"
             ],
             "modules" => []
           }
  end
end
