defmodule BrainCloud.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BrainCloud.Repo,
      {DNSCluster, query: Application.get_env(:brain_cloud, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BrainCloud.PubSub}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BrainCloud.Supervisor)
  end
end
