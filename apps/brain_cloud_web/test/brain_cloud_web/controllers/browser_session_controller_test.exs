defmodule BrainCloudWeb.BrowserSessionControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  alias BrainCloud.Accounts

  test "logout revokes only the current tracked session, clears its cookie, and is idempotent", %{
    conn: conn,
    identity: identity
  } do
    {_scope, first_token} = browser_session(identity.user.email)
    {_scope, second_token} = browser_session(identity.user.email, 61)

    conn =
      conn
      |> init_test_session(%{"browser_session_token" => first_token})
      |> delete(~p"/session")

    assert redirected_to(conn) == "/"
    assert is_nil(get_session(conn, "browser_session_token"))
    assert {:error, :unauthorized} = Accounts.authenticate_browser_session(first_token)
    assert {:ok, _scope, nil} = Accounts.authenticate_browser_session(second_token)

    conn = conn |> recycle() |> delete(~p"/session")
    assert redirected_to(conn) == "/"
  end

  defp browser_session(email, offset \\ 0) do
    now = DateTime.add(DateTime.utc_now(:microsecond), offset, :second)

    assert {:ok, {:deliver, challenge, raw_login_token, _user}} =
             Accounts.request_browser_login(email, now: now)

    assert {:ok, _challenge} = Accounts.mark_browser_login_sent(challenge.id, now: now)
    assert {:ok, scope, session_token} = Accounts.confirm_browser_login(raw_login_token, now: now)
    {scope, session_token}
  end
end
