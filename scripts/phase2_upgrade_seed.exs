alias BrainCloud.Repo

Ecto.Adapters.SQL.query!(Repo, """
INSERT INTO projects (
  id,
  name,
  creator_actor_id,
  inserted_at,
  updated_at
) VALUES (
  '11111111-1111-4111-8111-111111111111',
  'Legacy project',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '2026-07-01 12:00:00.123456Z',
  '2026-07-02 12:00:00.123456Z'
);
""")

Ecto.Adapters.SQL.query!(Repo, """
INSERT INTO memories (
  id,
  project_id,
  inserted_at,
  updated_at
) VALUES (
  '22222222-2222-4222-8222-222222222222',
  '11111111-1111-4111-8111-111111111111',
  '2026-07-03 12:00:00.123456Z',
  '2026-07-04 12:00:00.123456Z'
);
""")

Ecto.Adapters.SQL.query!(Repo, """
INSERT INTO memory_revisions (
  id,
  memory_id,
  revision_number,
  title,
  content,
  content_type,
  content_hash,
  actor_id,
  inserted_at,
  updated_at
) VALUES (
  '33333333-3333-4333-8333-333333333333',
  '22222222-2222-4222-8222-222222222222',
  1,
  'Legacy Phoenix notes',
  'Durable legacy Phoenix memory',
  'text/markdown',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '2026-07-05 12:00:00.123456Z',
  '2026-07-06 12:00:00.123456Z'
);
""")
