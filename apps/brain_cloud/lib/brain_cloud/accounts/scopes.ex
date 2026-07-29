defmodule BrainCloud.Accounts.Scopes do
  @moduledoc false

  @all ~w(projects.create memory.write memory.read search.keyword members.manage tokens.manage)

  def all, do: @all
  def allowed?(scopes, scope), do: scope in scopes
  def subset?(requested, granted), do: MapSet.subset?(MapSet.new(requested), MapSet.new(granted))
end
