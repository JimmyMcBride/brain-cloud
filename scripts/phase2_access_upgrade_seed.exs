alias BrainCloud.Accounts
alias BrainCloud.Accounts.{ApiToken, OrganizationMembership}
alias BrainCloud.Repo

import Ecto.Query

{:ok, bootstrap} =
  Accounts.bootstrap_owner(
    %{email: "legacy-owner@example.test", display_name: "Legacy Owner"},
    adopt_phase_one: true
  )

{:ok, bootstrap_auth} = Accounts.authenticate(bootstrap.raw_token)

{:ok, _narrow_token, _raw_token} =
  Accounts.create_api_token(bootstrap_auth, %{
    name: "Legacy narrow reader",
    scopes: ["memory.read"]
  })

{:ok, _full_token, _raw_token} =
  Accounts.create_api_token(bootstrap_auth, %{
    name: "Legacy full owner",
    scopes: [
      "projects.create",
      "projects.manage_access",
      "memory.write",
      "memory.read",
      "search.keyword",
      "members.manage",
      "tokens.manage"
    ]
  })

{1, nil} =
  Repo.update_all(
    from(token in ApiToken, where: token.id == ^bootstrap.token.id),
    set: [scopes: ["members.manage", "tokens.manage"]]
  )

persisted_bootstrap = Repo.get!(ApiToken, bootstrap.token.id)
false = "projects.manage_access" in persisted_bootstrap.scopes
false = "teams.manage" in persisted_bootstrap.scopes

inactive_user_id = Ecto.UUID.cast!("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")

Repo.update_all(
  from(membership in OrganizationMembership,
    where: membership.user_id == ^inactive_user_id
  ),
  set: [deactivated_at: DateTime.utc_now(:microsecond)]
)
