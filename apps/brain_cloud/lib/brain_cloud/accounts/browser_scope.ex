defmodule BrainCloud.Accounts.BrowserScope do
  @moduledoc """
  The request-local human browser identity and selected organization context.
  """

  defstruct [:user, :session, :selected_membership, :organization, :role, memberships: []]
end
