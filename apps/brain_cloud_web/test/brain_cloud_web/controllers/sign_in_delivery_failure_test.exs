defmodule BrainCloudWeb.SignInDeliveryFailureTest do
  use BrainCloudWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  alias BrainCloud.Accounts.BrowserLoginChallenge
  alias BrainCloud.Repo

  defmodule FailingAdapter do
    use Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: raise("relay unavailable")
  end

  defmodule SupersedingAdapter do
    use Swoosh.Adapter

    alias BrainCloud.Accounts

    @impl true
    def deliver(email, _config) do
      [{_name, address}] = email.to
      {:ok, {:deliver, _challenge, _raw_token, _user}} = Accounts.request_browser_login(address)
      {:ok, %{}}
    end
  end

  setup do
    original = Application.fetch_env!(:brain_cloud_web, BrainCloudWeb.Mailer)

    on_exit(fn -> Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, original) end)
  end

  test "delivery failure is non-enumerating, invalidates the challenge, and logs no email", %{
    conn: conn,
    identity: identity
  } do
    Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, adapter: FailingAdapter)

    log =
      capture_log(fn ->
        html =
          conn
          |> post(~p"/sign-in", %{"sign_in" => %{"email" => identity.user.email}})
          |> html_response(200)

        assert html =~ "If this email can sign in, a link is on its way."
      end)

    challenge = Repo.one!(BrowserLoginChallenge)
    refute is_nil(challenge.revoked_at)
    refute log =~ identity.user.email
    refute log =~ "bcl1_"
    assert log =~ "browser sign-in delivery failed"
    refute_email_sent()
  end

  test "a challenge superseded while its email is delivered is a benign accepted request", %{
    conn: conn,
    identity: identity
  } do
    Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, adapter: SupersedingAdapter)

    log =
      capture_log(fn ->
        html =
          conn
          |> post(~p"/sign-in", %{"sign_in" => %{"email" => identity.user.email}})
          |> html_response(200)

        assert html =~ "If this email can sign in, a link is on its way."
      end)

    [superseded, current] =
      Repo.all(from(challenge in BrowserLoginChallenge, order_by: challenge.inserted_at))

    refute is_nil(superseded.revoked_at)
    assert is_nil(current.revoked_at)
    assert is_nil(current.consumed_at)
    refute log =~ "browser sign-in delivery failed"
    refute log =~ "browser sign-in request failed"
  end
end
