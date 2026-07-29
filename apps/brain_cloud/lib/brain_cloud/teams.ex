defmodule BrainCloud.Teams do
  @moduledoc """
  Owns organization team lifecycle and membership links.
  """

  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Accounts.OrganizationMembership
  alias BrainCloud.Repo
  alias BrainCloud.Teams.Team
  alias BrainCloud.Teams.TeamMembership
  alias Ecto.Changeset

  def create_team(attrs, %AuthContext{} = auth) do
    attrs = Map.new(attrs)

    with :ok <- authorize_management(auth) do
      Repo.transaction(fn ->
        with {:ok, team} <-
               %Team{}
               |> Team.changeset(%{
                 organization_id: auth.organization_id,
                 name: attribute(attrs, :name)
               })
               |> Repo.insert(),
             {:ok, _event} <-
               audit(auth, "team.create", team, %{"name" => team.name}) |> Repo.insert() do
          team
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> unwrap()
    end
  end

  def list_teams(%AuthContext{} = auth) do
    with :ok <- authorize_management(auth) do
      {:ok,
       Repo.all(
         from team in Team,
           where: team.organization_id == ^auth.organization_id,
           order_by: [asc: team.inserted_at, asc: team.id]
       )}
    end
  end

  def rename_team(team_id, name, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, team_id} <- Ecto.UUID.cast(team_id) do
      Repo.transaction(fn ->
        case team_for_update(team_id, auth.organization_id) do
          nil ->
            Repo.rollback(:team_not_found)

          team ->
            changeset = Team.changeset(team, %{name: name})

            with {:ok, validated} <- Changeset.apply_action(changeset, :update) do
              if validated.name == team.name do
                team
              else
                with {:ok, updated} <- Repo.update(changeset),
                     {:ok, _event} <-
                       audit(auth, "team.rename", updated, %{
                         "name" => updated.name,
                         "previous_name" => team.name
                       })
                       |> Repo.insert() do
                  updated
                else
                  {:error, reason} -> Repo.rollback(reason)
                end
              end
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap()
    else
      :error -> {:error, :team_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def deactivate_team(team_id, %AuthContext{} = auth),
    do: change_active(team_id, false, auth)

  def reactivate_team(team_id, %AuthContext{} = auth),
    do: change_active(team_id, true, auth)

  def list_team_memberships(team_id, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, team_id} <- Ecto.UUID.cast(team_id),
         %Team{} <- tenant_team(team_id, auth.organization_id) do
      {:ok,
       Repo.all(
         from link in TeamMembership,
           where: link.team_id == ^team_id and link.organization_id == ^auth.organization_id,
           order_by: [asc: link.inserted_at, asc: link.id]
       )}
    else
      :error -> {:error, :team_not_found}
      nil -> {:error, :team_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def put_team_membership(team_id, membership_id, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, team_id} <- Ecto.UUID.cast(team_id),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        with %Team{} = team <- team_for_update(team_id, auth.organization_id),
             :ok <- ensure_team_active(team),
             %OrganizationMembership{} = membership <-
               membership_for_update(membership_id, auth.organization_id),
             :ok <- ensure_membership_active(membership) do
          case Repo.get_by(TeamMembership,
                 organization_id: auth.organization_id,
                 team_id: team_id,
                 organization_membership_id: membership_id
               ) do
            %TeamMembership{} = link ->
              link

            nil ->
              with {:ok, link} <-
                     %TeamMembership{}
                     |> TeamMembership.changeset(%{
                       organization_id: auth.organization_id,
                       team_id: team_id,
                       organization_membership_id: membership_id
                     })
                     |> Repo.insert(),
                   {:ok, _event} <-
                     audit_link(auth, "team_membership.add", link) |> Repo.insert() do
                link
              else
                {:error, reason} -> Repo.rollback(reason)
              end
          end
        else
          nil -> Repo.rollback(missing_membership_resource(team_id, membership_id, auth))
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> unwrap()
    else
      :error -> {:error, malformed_membership_resource(team_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete_team_membership(team_id, membership_id, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, team_id} <- Ecto.UUID.cast(team_id),
         {:ok, membership_id} <- Ecto.UUID.cast(membership_id) do
      Repo.transaction(fn ->
        with %Team{} <- team_for_update(team_id, auth.organization_id),
             %OrganizationMembership{} <-
               membership_for_update(membership_id, auth.organization_id) do
          case Repo.get_by(TeamMembership,
                 organization_id: auth.organization_id,
                 team_id: team_id,
                 organization_membership_id: membership_id
               ) do
            nil ->
              nil

            link ->
              with {:ok, deleted} <- Repo.delete(link),
                   {:ok, _event} <-
                     audit_link(auth, "team_membership.remove", link) |> Repo.insert() do
                deleted
              else
                {:error, reason} -> Repo.rollback(reason)
              end
          end
        else
          nil -> Repo.rollback(missing_membership_resource(team_id, membership_id, auth))
        end
      end)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, malformed_membership_resource(team_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp change_active(team_id, active?, auth) do
    with :ok <- authorize_management(auth),
         {:ok, team_id} <- Ecto.UUID.cast(team_id) do
      Repo.transaction(fn ->
        case team_for_update(team_id, auth.organization_id) do
          nil ->
            Repo.rollback(:team_not_found)

          %Team{deactivated_at: nil} = team when active? ->
            team

          %Team{deactivated_at: at} = team when not active? and not is_nil(at) ->
            team

          team ->
            action = if active?, do: "team.reactivate", else: "team.deactivate"
            at = if active?, do: nil, else: DateTime.utc_now(:microsecond)

            with {:ok, updated} <-
                   team |> Changeset.change(deactivated_at: at) |> Repo.update(),
                 {:ok, _event} <- audit(auth, action, updated) |> Repo.insert() do
              updated
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap()
    else
      :error -> {:error, :team_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize_management(%AuthContext{role: "owner"} = auth) do
    if Accounts.authorized?(auth, "teams.manage"), do: :ok, else: {:error, :forbidden}
  end

  defp authorize_management(_auth), do: {:error, :forbidden}

  defp tenant_team(id, organization_id),
    do: Repo.get_by(Team, id: id, organization_id: organization_id)

  defp team_for_update(id, organization_id) do
    Repo.one(
      from team in Team,
        where: team.id == ^id and team.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp membership_for_update(id, organization_id) do
    Repo.one(
      from membership in OrganizationMembership,
        where: membership.id == ^id and membership.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp ensure_team_active(%Team{deactivated_at: nil}), do: :ok
  defp ensure_team_active(_team), do: {:error, :team_inactive}
  defp ensure_membership_active(%OrganizationMembership{deactivated_at: nil}), do: :ok
  defp ensure_membership_active(_membership), do: {:error, :membership_inactive}

  defp malformed_membership_resource(team_id) do
    if Ecto.UUID.cast(team_id) == :error, do: :team_not_found, else: :membership_not_found
  end

  defp missing_membership_resource(team_id, membership_id, auth) do
    cond do
      is_nil(tenant_team(team_id, auth.organization_id)) -> :team_not_found
      is_nil(membership_for_update(membership_id, auth.organization_id)) -> :membership_not_found
    end
  end

  defp audit(auth, action, team, metadata \\ %{}) do
    Accounts.audit_changeset(auth, action, "team", team.id, metadata)
  end

  defp audit_link(auth, action, link) do
    Accounts.audit_changeset(auth, action, "team_membership", link.id, %{
      "team_id" => link.team_id,
      "membership_id" => link.organization_membership_id
    })
  end

  defp unwrap({:ok, value}), do: {:ok, value}
  defp unwrap({:error, reason}), do: {:error, reason}

  defp attribute(attrs, key),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
end
