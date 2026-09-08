defmodule BrainCloud.SystemInfo do
  @moduledoc """
  Reports the stable public compatibility surface for this server.
  """

  @spec get() :: map()
  def get do
    %{
      server: "brain-cloud",
      server_version: "0.0.0-dev",
      protocol_version: "v1",
      capabilities: [
        "system.info",
        "projects.create",
        "projects.read",
        "projects.manage_access",
        "memory.write",
        "memory.read",
        "search.keyword",
        "members.manage",
        "teams.manage",
        "agents.manage",
        "tokens.manage"
      ],
      modules: []
    }
  end
end
