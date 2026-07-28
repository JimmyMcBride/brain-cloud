defmodule BrainCloudWeb.SystemInfoController do
  use BrainCloudWeb, :controller

  def show(conn, _params) do
    json(conn, BrainCloud.SystemInfo.get())
  end
end
