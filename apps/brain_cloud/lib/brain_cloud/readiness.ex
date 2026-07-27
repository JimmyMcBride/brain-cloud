defmodule BrainCloud.Readiness do
  @moduledoc """
  Checks whether Brain Cloud can reach its transactional database.
  """

  @spec ready?((-> {:ok, term()} | {:error, term()})) :: boolean()
  def ready?(query \\ &query_database/0) do
    case query.() do
      {:ok, _result} -> true
      {:error, _reason} -> false
    end
  rescue
    _error -> false
  catch
    :exit, _reason -> false
  end

  defp query_database do
    Ecto.Adapters.SQL.query(BrainCloud.Repo, "SELECT 1", [], timeout: 2_000)
  end
end
