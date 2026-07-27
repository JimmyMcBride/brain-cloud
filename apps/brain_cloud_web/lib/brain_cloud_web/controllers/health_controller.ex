defmodule BrainCloudWeb.HealthController do
  use BrainCloudWeb, :controller

  def show(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
