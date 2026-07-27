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
      capabilities: ["system.info"],
      modules: []
    }
  end
end
