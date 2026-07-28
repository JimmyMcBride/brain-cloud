defmodule BrainCloud.Accounts.AuthContext do
  @enforce_keys [
    :user_id,
    :organization_id,
    :membership_id,
    :role,
    :api_token_id,
    :scopes
  ]
  defstruct @enforce_keys
end
