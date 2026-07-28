defmodule BrainCloud.Release do
  @moduledoc false

  @app :brain_cloud

  def migrate do
    Application.load(@app)

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _result, _apps} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def bootstrap_owner_from_env do
    with {:ok, email} <- fetch_env("OWNER_EMAIL"),
         {:ok, display_name} <- fetch_env("OWNER_DISPLAY_NAME") do
      attrs = %{
        email: email,
        display_name: display_name,
        organization_name: System.get_env("ORGANIZATION_NAME"),
        organization_slug: System.get_env("ORGANIZATION_SLUG")
      }

      opts = [
        adopt_phase_one: enabled?("ADOPT_PHASE_ONE"),
        rotate_token: enabled?("ROTATE_TOKEN")
      ]

      with_repo(fn -> BrainCloud.Accounts.bootstrap_owner(attrs, opts) end)
    end
    |> case do
      {:ok, result} ->
        output = %{
          status: if(result.created, do: "created", else: "existing"),
          user_id: result.user.id,
          organization_id: result.organization.id,
          membership_id: result.membership.id,
          token: result.raw_token
        }

        IO.puts(Jason.encode!(output))

      {:error, reason} ->
        fail_bootstrap(reason)
    end
  end

  defp with_repo(function) do
    Application.load(@app)

    [repo] = Application.fetch_env!(@app, :ecto_repos)
    {:ok, result, _apps} = Ecto.Migrator.with_repo(repo, fn _repo -> function.() end)
    result
  end

  defp fetch_env(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _missing -> {:error, {:missing_environment, name}}
    end
  end

  defp enabled?(name), do: System.get_env(name) in ~w(true 1)

  defp fail_bootstrap(reason) do
    IO.puts(:stderr, "bootstrap failed: #{safe_error(reason)}")
    System.halt(1)
  end

  defp safe_error(%Ecto.Changeset{}), do: "validation failed"
  defp safe_error({:missing_environment, name}), do: "environment variable #{name} is missing"
  defp safe_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp safe_error(_reason), do: "unexpected error"
end
