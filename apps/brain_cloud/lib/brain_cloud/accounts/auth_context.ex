defmodule BrainCloud.Accounts.AuthContext do
  @enforce_keys [
    :principal_type,
    :principal_id,
    :organization_id,
    :role,
    :api_token_id,
    :scopes
  ]
  defstruct @enforce_keys ++ [user_id: nil, membership_id: nil, agent_id: nil]
end
