defmodule BrainCloudWeb.HomeLiveTest do
  use BrainCloudWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "shows the honest bootstrap surface", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Brain Cloud"
    assert html =~ "Phase 1 API"
    assert html =~ "durable project memory through the public API"
    assert html =~ "no product UI"
    refute html =~ "Peace of mind from prototype to production"
  end
end
