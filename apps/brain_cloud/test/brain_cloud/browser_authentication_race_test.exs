defmodule BrainCloud.BrowserAuthenticationRaceTest do
  use ExUnit.Case, async: false

  import BrainCloud.DataCase, only: [identity_fixture: 0]
  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.BrowserSession
  alias BrainCloud.Accounts.UserAuthEvent
  alias BrainCloud.Repo
  alias Ecto.Adapters.SQL.Sandbox

  test "concurrent confirmation consumes once with no duplicate session or events" do
    setup = unboxed(&login_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    results =
      race(
        fn -> Accounts.confirm_browser_login(setup.login_token) end,
        fn -> Accounts.confirm_browser_login(setup.login_token) end
      )

    assert Enum.count(results, &match?({:ok, _scope, _session_token}, &1)) == 1
    assert Enum.count(results, &(&1 == {:error, :login_unavailable})) == 1
    assert unboxed(fn -> Repo.aggregate(BrowserSession, :count) end) == 1
    assert unboxed(fn -> event_count("email.verify") end) == 1
    assert unboxed(fn -> event_count("session.create") end) == 1
  end

  test "concurrent reissue creates one replacement and one event" do
    setup = unboxed(&session_setup/0)
    on_exit(fn -> unboxed(fn -> cleanup(setup) end) end)

    unboxed(fn ->
      Repo.update_all(from(session in BrowserSession, where: session.id == ^setup.session_id),
        set: [
          inserted_at: DateTime.add(DateTime.utc_now(:microsecond), -8 * 24 * 60 * 60, :second)
        ]
      )
    end)

    results =
      race(
        fn -> Accounts.authenticate_browser_session(setup.session_token) end,
        fn -> Accounts.authenticate_browser_session(setup.session_token) end
      )

    assert Enum.count(
             results,
             &match?({:ok, _scope, replacement} when is_binary(replacement), &1)
           ) == 1

    assert Enum.count(results, &(&1 == {:error, :unauthorized})) == 1
    assert unboxed(fn -> Repo.aggregate(BrowserSession, :count) end) == 2
    assert unboxed(fn -> event_count("session.reissue") end) == 1
  end

  defp session_setup do
    setup = login_setup()
    {:ok, scope, session_token} = Accounts.confirm_browser_login(setup.login_token)
    Map.merge(setup, %{session_id: scope.session.id, session_token: session_token})
  end

  defp login_setup do
    identity = identity_fixture()

    {:ok, {:deliver, challenge, login_token, _user}} =
      Accounts.request_browser_login(identity.user.email)

    {:ok, _challenge} = Accounts.mark_browser_login_sent(challenge.id)

    %{
      user_id: identity.user.id,
      organization_id: identity.organization.id,
      login_token: login_token
    }
  end

  defp race(left_fun, right_fun) do
    parent = self()

    tasks =
      for {side, fun} <- [left: left_fun, right: right_fun] do
        Task.async(fn ->
          unboxed(fn ->
            backend_pid = backend_pid()
            send(parent, {:race_ready, side, self(), backend_pid})
            receive do: (:race_go -> :ok)
            {backend_pid, fun.()}
          end)
        end)
      end

    assert_receive {:race_ready, :left, left_pid, left_backend}, 5_000
    assert_receive {:race_ready, :right, right_pid, right_backend}, 5_000
    assert left_backend != right_backend
    send(left_pid, :race_go)
    send(right_pid, :race_go)

    Enum.map(tasks, fn task ->
      {_backend_pid, result} = Task.await(task, 5_000)
      result
    end)
  end

  defp event_count(action) do
    Repo.aggregate(from(event in UserAuthEvent, where: event.action == ^action), :count, :id)
  end

  defp backend_pid do
    %{rows: [[pid]]} = Repo.query!("SELECT pg_backend_pid()")
    pid
  end

  defp cleanup(setup) do
    user_id = Ecto.UUID.dump!(setup.user_id)
    organization_id = Ecto.UUID.dump!(setup.organization_id)

    Repo.query!("DELETE FROM user_auth_events WHERE user_id = $1", [user_id])
    Repo.query!("DELETE FROM browser_sessions WHERE user_id = $1", [user_id])
    Repo.query!("DELETE FROM browser_login_challenges WHERE user_id = $1", [user_id])
    Repo.query!("DELETE FROM audit_events WHERE organization_id = $1", [organization_id])

    Repo.query!(
      "DELETE FROM api_tokens WHERE membership_id IN (SELECT id FROM organization_memberships WHERE organization_id = $1)",
      [organization_id]
    )

    Repo.query!("DELETE FROM organization_memberships WHERE organization_id = $1", [
      organization_id
    ])

    Repo.query!("DELETE FROM organizations WHERE id = $1", [organization_id])
    Repo.query!("DELETE FROM users WHERE id = $1", [user_id])
  end

  defp unboxed(fun), do: Sandbox.unboxed_run(Repo, fun)
end
