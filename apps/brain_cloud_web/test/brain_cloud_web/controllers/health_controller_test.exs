defmodule BrainCloudWeb.HealthControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  test "returns process health", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
