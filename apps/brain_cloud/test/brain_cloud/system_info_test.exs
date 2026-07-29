defmodule BrainCloud.SystemInfoTest do
  use ExUnit.Case, async: true

  test "reports the public compatibility surface" do
    assert BrainCloud.SystemInfo.get() == %{
             server: "brain-cloud",
             server_version: "0.0.0-dev",
             protocol_version: "v1",
             capabilities: [
               "system.info",
               "projects.create",
               "projects.manage_access",
               "memory.write",
               "memory.read",
               "search.keyword",
               "members.manage",
               "teams.manage",
               "tokens.manage"
             ],
             modules: []
           }
  end
end
