defmodule BrainCloud.Agents do
  @moduledoc """
  Owns organization agent lifecycle and read-only credentials.
  """

  import Ecto.Query

  alias BrainCloud.Accounts
  alias BrainCloud.Accounts.ApiToken
  alias BrainCloud.Accounts.AuthContext
  alias BrainCloud.Agents.Agent
  alias BrainCloud.Repo
  alias Ecto.Changeset

  def create_agent(attrs, %AuthContext{} = auth) do
    attrs = Map.new(attrs)

    with :ok <- authorize_management(auth) do
      Repo.transaction(fn ->
        with {:ok, agent} <-
               %Agent{}
               |> Agent.changeset(%{
                 organization_id: auth.organization_id,
                 name: attribute(attrs, :name)
               })
               |> Repo.insert(),
             {:ok, _event} <-
               audit(auth, "agent.create", agent, %{"name" => agent.name}) |> Repo.insert() do
          agent
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> unwrap()
    end
  end

  def list_agents(%AuthContext{} = auth) do
    with :ok <- authorize_management(auth) do
      {:ok,
       Repo.all(
         from agent in Agent,
           where: agent.organization_id == ^auth.organization_id,
           order_by: [asc: agent.inserted_at, asc: agent.id]
       )}
    end
  end

  def rename_agent(agent_id, name, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, agent_id} <- Ecto.UUID.cast(agent_id) do
      Repo.transaction(fn ->
        case agent_for_update(agent_id, auth.organization_id) do
          nil ->
            Repo.rollback(:agent_not_found)

          agent ->
            changeset = Agent.changeset(agent, %{name: name})

            with {:ok, validated} <- Changeset.apply_action(changeset, :update) do
              if validated.name == agent.name do
                agent
              else
                with {:ok, updated} <- Repo.update(changeset),
                     {:ok, _event} <-
                       audit(auth, "agent.rename", updated, %{
                         "name" => updated.name,
                         "previous_name" => agent.name
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
      :error -> {:error, :agent_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def deactivate_agent(agent_id, %AuthContext{} = auth),
    do: change_active(agent_id, false, auth)

  def reactivate_agent(agent_id, %AuthContext{} = auth),
    do: change_active(agent_id, true, auth)

  def create_agent_token(agent_id, attrs, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, agent_id} <- Ecto.UUID.cast(agent_id) do
      Repo.transaction(fn ->
        case agent_for_update(agent_id, auth.organization_id) do
          nil ->
            Repo.rollback(:agent_not_found)

          %Agent{deactivated_at: at} when not is_nil(at) ->
            Repo.rollback(:agent_inactive)

          %Agent{} = agent ->
            with {:ok, {token, raw_token}} <- Accounts.issue_agent_token(agent.id, attrs),
                 {:ok, _event} <-
                   Accounts.audit_changeset(
                     auth,
                     "agent_token.create",
                     "api_token",
                     token.id,
                     %{
                       "agent_id" => agent.id,
                       "name" => token.name,
                       "scopes" => token.scopes
                     }
                   )
                   |> Repo.insert() do
              {token, raw_token}
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> case do
        {:ok, {token, raw_token}} -> {:ok, token, raw_token}
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, :agent_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_agent_tokens(agent_id, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, agent_id} <- Ecto.UUID.cast(agent_id),
         %Agent{} <- tenant_agent(agent_id, auth.organization_id) do
      {:ok,
       Repo.all(
         from token in ApiToken,
           where: token.agent_id == ^agent_id,
           order_by: [asc: token.inserted_at, asc: token.id]
       )}
    else
      :error -> {:error, :agent_not_found}
      nil -> {:error, :agent_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def revoke_agent_token(agent_id, token_id, %AuthContext{} = auth) do
    with :ok <- authorize_management(auth),
         {:ok, agent_id} <- Ecto.UUID.cast(agent_id) do
      Repo.transaction(fn ->
        case agent_for_update(agent_id, auth.organization_id) do
          nil ->
            Repo.rollback(:agent_not_found)

          %Agent{} = agent ->
            with {:ok, token_id} <- cast_token_id(token_id),
                 %ApiToken{} = token <- agent_token_for_update(agent.id, token_id) do
              revoke_token(token, agent, auth)
            else
              :error -> Repo.rollback(:token_not_found)
              nil -> Repo.rollback(:token_not_found)
            end
        end
      end)
      |> case do
        {:ok, _token} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :error -> {:error, :agent_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp change_active(agent_id, active?, auth) do
    with :ok <- authorize_management(auth),
         {:ok, agent_id} <- Ecto.UUID.cast(agent_id) do
      Repo.transaction(fn ->
        case agent_for_update(agent_id, auth.organization_id) do
          nil ->
            Repo.rollback(:agent_not_found)

          %Agent{deactivated_at: nil} = agent when active? ->
            agent

          %Agent{deactivated_at: at} = agent when not active? and not is_nil(at) ->
            agent

          agent ->
            action = if active?, do: "agent.reactivate", else: "agent.deactivate"
            at = if active?, do: nil, else: DateTime.utc_now(:microsecond)

            with {:ok, updated} <-
                   agent |> Changeset.change(deactivated_at: at) |> Repo.update(),
                 revoked_count <- maybe_revoke_tokens(agent.id, active?),
                 {:ok, _event} <-
                   audit(
                     auth,
                     action,
                     updated,
                     if(active?, do: %{}, else: %{"revoked_token_count" => revoked_count})
                   )
                   |> Repo.insert() do
              updated
            else
              {:error, reason} -> Repo.rollback(reason)
            end
        end
      end)
      |> unwrap()
    else
      :error -> {:error, :agent_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_revoke_tokens(_agent_id, true), do: 0

  defp maybe_revoke_tokens(agent_id, false) do
    now = DateTime.utc_now(:microsecond)

    {count, _tokens} =
      Repo.update_all(
        from(token in ApiToken,
          where: token.agent_id == ^agent_id and is_nil(token.revoked_at)
        ),
        set: [revoked_at: now, updated_at: now]
      )

    count
  end

  defp revoke_token(%ApiToken{revoked_at: at} = token, _agent, _auth) when not is_nil(at),
    do: token

  defp revoke_token(token, agent, auth) do
    with {:ok, revoked} <-
           token
           |> Changeset.change(revoked_at: DateTime.utc_now(:microsecond))
           |> Repo.update(),
         {:ok, _event} <-
           Accounts.audit_changeset(
             auth,
             "agent_token.revoke",
             "api_token",
             token.id,
             %{"agent_id" => agent.id}
           )
           |> Repo.insert() do
      revoked
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp authorize_management(%AuthContext{role: "owner"} = auth) do
    if Accounts.authorized?(auth, "agents.manage"), do: :ok, else: {:error, :forbidden}
  end

  defp authorize_management(_auth), do: {:error, :forbidden}

  defp tenant_agent(id, organization_id),
    do: Repo.get_by(Agent, id: id, organization_id: organization_id)

  defp agent_for_update(id, organization_id) do
    Repo.one(
      from agent in Agent,
        where: agent.id == ^id and agent.organization_id == ^organization_id,
        lock: "FOR UPDATE"
    )
  end

  defp agent_token_for_update(agent_id, token_id) do
    Repo.one(
      from token in ApiToken,
        where: token.id == ^token_id and token.agent_id == ^agent_id,
        lock: "FOR UPDATE"
    )
  end

  defp cast_token_id(token_id), do: Ecto.UUID.cast(token_id)

  defp audit(auth, action, agent, metadata) do
    Accounts.audit_changeset(auth, action, "agent", agent.id, metadata)
  end

  defp unwrap({:ok, value}), do: {:ok, value}
  defp unwrap({:error, reason}), do: {:error, reason}

  defp attribute(attrs, key),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
end
