defmodule BrainCloudWeb.ReadinessController do
  use BrainCloudWeb, :controller

  def show(conn, _params) do
    checker =
      Application.get_env(:brain_cloud_web, :readiness_checker, BrainCloud.Readiness)

    if checker.ready?() do
      json(conn, %{status: "ready"})
    else
      conn
      |> put_status(:service_unavailable)
      |> json(%{status: "not_ready"})
    end
  end
end
