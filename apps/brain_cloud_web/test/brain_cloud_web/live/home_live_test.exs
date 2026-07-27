defmodule BrainCloudWeb.HomeLiveTest do
  use BrainCloudWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "shows the honest bootstrap surface", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Brain Cloud"
    assert html =~ "Server foundation"
    assert html =~ "protocol discovery and operational health only"
    refute html =~ "Peace of mind from prototype to production"
  end
end
