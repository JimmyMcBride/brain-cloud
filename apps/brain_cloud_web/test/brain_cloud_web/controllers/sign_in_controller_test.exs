defmodule BrainCloudWeb.SignInControllerTest do
  use BrainCloudWeb.ConnCase, async: true

  import Swoosh.TestAssertions

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.BrowserLoginChallenge
  alias BrainCloud.Accounts.BrowserSession
  alias BrainCloud.Repo

  @acknowledgement "If this email can sign in, a link is on its way."

  test "renders the existing-user sign-in page", %{conn: conn} do
    html = conn |> get(~p"/sign-in") |> html_response(200)

    assert html =~ "Sign in to Brain Cloud"
    assert html =~ "Closed enrollment"
    assert html =~ "sign_in[email]"
    refute html =~ "Create account"
  end

  test "eligible and unknown requests return the exact same acknowledgement", %{
    conn: conn,
    identity: identity
  } do
    eligible =
      conn
      |> post(~p"/sign-in", %{
        "sign_in" => %{"email" => "  #{String.upcase(identity.user.email)}  "}
      })
      |> html_response(200)

    assert eligible =~ @acknowledgement

    assert_email_sent(fn email ->
      assert email.to == [{identity.user.display_name, identity.user.email}]
      assert email.subject == "Sign in to Brain Cloud"
      assert email.text_body =~ "/sign-in/confirm#token=bcl1_"
      true
    end)

    unknown =
      build_conn()
      |> post(~p"/sign-in", %{"sign_in" => %{"email" => "unknown@example.test"}})
      |> html_response(200)

    assert without_csrf(unknown) == without_csrf(eligible)
    refute_email_sent()
  end

  test "confirmation token is absent from the GET request, response, and final redirect", %{
    conn: conn,
    identity: identity
  } do
    post(conn, ~p"/sign-in", %{"sign_in" => %{"email" => identity.user.email}})
    raw_login_token = delivered_login_token()
    challenge = Repo.one!(BrowserLoginChallenge)

    confirm_html = conn |> get(~p"/sign-in/confirm") |> html_response(200)
    assert confirm_html =~ "Confirm sign-in"
    refute confirm_html =~ raw_login_token
    assert is_nil(Repo.get!(BrowserLoginChallenge, challenge.id).consumed_at)

    conn =
      conn
      |> post(~p"/sign-in/confirm", %{
        "login" => %{"token" => raw_login_token},
        "return_to" => "https://attacker.example"
      })

    assert redirected_to(conn) == "/"
    refute get_resp_header(conn, "location") |> List.first() =~ raw_login_token

    session_token = get_session(conn, "browser_session_token")
    assert String.starts_with?(session_token, "bcs1_")
    refute session_token == raw_login_token
    assert Repo.aggregate(BrowserSession, :count) == 1

    cookie = conn.resp_cookies["_brain_cloud_web_session"]
    assert cookie.http_only
    assert cookie.same_site == "Lax"
    assert cookie.max_age == 14 * 24 * 60 * 60
    refute cookie.value =~ identity.user.email
    refute cookie.value =~ session_token
  end

  test "invalid confirmation has one public result and no session", %{conn: conn} do
    conn = post(conn, ~p"/sign-in/confirm", %{"login" => %{"token" => "wrong"}})

    assert redirected_to(conn) == "/sign-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "invalid or has expired"
    assert is_nil(get_session(conn, "browser_session_token"))
  end

  test "confirmation consumption rejects a POST without a CSRF token", %{identity: identity} do
    assert {:ok, {:deliver, challenge, raw_login_token, _user}} =
             Accounts.request_browser_login(identity.user.email)

    assert {:ok, _challenge} = Accounts.mark_browser_login_sent(challenge.id)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      Plug.Test.conn(:post, "/sign-in/confirm", %{"login" => %{"token" => raw_login_token}})
      |> BrainCloudWeb.Endpoint.call([])
    end

    assert is_nil(Repo.get!(BrowserLoginChallenge, challenge.id).consumed_at)
    assert Repo.aggregate(BrowserSession, :count) == 0
  end

  test "browser sessions never authenticate API routes", %{conn: conn, identity: identity} do
    {_scope, session_token} = browser_session(identity.user.email)

    conn =
      conn
      |> init_test_session(%{"browser_session_token" => session_token})
      |> get(~p"/v1/organization/memberships")

    assert json_response(conn, 401) == %{
             "error" => %{
               "code" => "unauthorized",
               "details" => %{},
               "message" => "Authentication required"
             }
           }
  end

  test "API bearer credentials never authenticate the browser", %{conn: conn, identity: identity} do
    html =
      conn
      |> put_req_header("authorization", "Bearer #{identity.raw_token}")
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~s(id="signed-out")
    refute html =~ ~s(id="signed-in")
  end

  defp delivered_login_token do
    assert_receive {:email, email}
    [raw_token] = Regex.run(~r/bcl1_[0-9a-f]{32}_[A-Za-z0-9_-]{43}/, email.text_body)
    raw_token
  end

  defp browser_session(email) do
    assert {:ok, {:deliver, challenge, raw_login_token, _user}} =
             Accounts.request_browser_login(email)

    assert {:ok, _challenge} = Accounts.mark_browser_login_sent(challenge.id)
    assert {:ok, scope, session_token} = Accounts.confirm_browser_login(raw_login_token)
    {scope, session_token}
  end

  defp without_csrf(html) do
    Regex.replace(~r/(<meta name="csrf-token" content=")[^"]+("\s*\/?>)/, html, "\\1FILTERED\\2")
  end
end
