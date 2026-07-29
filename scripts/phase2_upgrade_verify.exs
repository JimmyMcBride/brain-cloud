alias BrainCloud.{Accounts, Memories, Projects, Repo}
alias BrainCloud.Accounts.{OrganizationMembership, User}

import Ecto.Query

{:ok, bootstrap} =
  Accounts.bootstrap_owner(
    %{email: "legacy-owner@example.test", display_name: "Legacy Owner"},
    adopt_phase_one: true
  )

true = bootstrap.organization.id == Accounts.phase_one_organization_id()
true = is_binary(bootstrap.raw_token)
{:ok, auth} = Accounts.authenticate(bootstrap.raw_token)

project = Projects.get_project("11111111-1111-4111-8111-111111111111", auth.organization_id)
true = project.name == "Legacy project"
true = project.creator_actor_id == "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
true = project.inserted_at == ~U[2026-07-01 12:00:00.123456Z]
true = project.updated_at == ~U[2026-07-02 12:00:00.123456Z]

memory =
  Memories.get_memory(
    project.id,
    "22222222-2222-4222-8222-222222222222",
    auth.organization_id
  )

[revision] = memory.revisions
true = memory.inserted_at == ~U[2026-07-03 12:00:00.123456Z]
true = memory.updated_at == ~U[2026-07-04 12:00:00.123456Z]
true = revision.content == "Durable legacy Phoenix memory"
true = revision.content_hash == String.duplicate("a", 64)
true = revision.actor_id == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
true = revision.inserted_at == ~U[2026-07-05 12:00:00.123456Z]
true = revision.updated_at == ~U[2026-07-06 12:00:00.123456Z]

{:ok, [result]} = Memories.search(project.id, "phoenix", auth.organization_id)
true = result.memory_id == memory.id
true = result.actor_id == revision.actor_id
true = result.content_hash == revision.content_hash

true = Repo.aggregate(User, :count, :id) == 3
true = Repo.aggregate(OrganizationMembership, :count, :id) == 3

synthetic_ids =
  Repo.all(
    from user in User,
      where:
        user.id in ^[
          "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
          "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        ],
      select: user.id
  )

true =
  MapSet.new(synthetic_ids) ==
    MapSet.new([
      "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    ])

{:ok, membership} =
  Accounts.create_organization_membership(auth, %{
    email: "upgraded-member@example.test",
    display_name: "Upgraded Member",
    role: "member"
  })

{:ok, _token, raw_token} =
  Accounts.create_membership_api_token(auth, membership.id, %{
    name: "Upgrade reader",
    scopes: ["memory.read"]
  })

{:ok, member_auth} = Accounts.authenticate(raw_token)
true = member_auth.membership_id == membership.id

IO.puts("Phase 2B upgrade passed")
