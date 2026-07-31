alias BrainCloud.Repo

# Seed the historical Phase 2D schema with SQL. Current Ecto schemas include
# Phase 2E columns and associations that intentionally do not exist yet.
Ecto.Adapters.SQL.query!(Repo, """
INSERT INTO users (id, email, display_name, inserted_at, updated_at)
VALUES (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'legacy-owner@example.test',
  'Legacy Owner',
  NOW(),
  NOW()
);
""")

Ecto.Adapters.SQL.query!(Repo, """
INSERT INTO organization_memberships (
  id,
  user_id,
  organization_id,
  role,
  inserted_at,
  updated_at
) VALUES (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '00000000-0000-0000-0000-0000000000f1',
  'owner',
  NOW(),
  NOW()
);
""")

Ecto.Adapters.SQL.query!(Repo, """
INSERT INTO api_tokens (
  id,
  membership_id,
  public_id,
  token_digest,
  name,
  scopes,
  bootstrap,
  inserted_at,
  updated_at
) VALUES
  (
    '44444444-4444-4444-8444-444444444444',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '44444444444444444444444444444444',
    decode(repeat('04', 32), 'hex'),
    'Bootstrap owner',
    ARRAY['projects.manage_access', 'members.manage', 'tokens.manage'],
    TRUE,
    NOW(),
    NOW()
  ),
  (
    '55555555-5555-4555-8555-555555555555',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '55555555555555555555555555555555',
    decode(repeat('05', 32), 'hex'),
    'Legacy narrow reader',
    ARRAY['memory.read'],
    FALSE,
    NOW(),
    NOW()
  ),
  (
    '66666666-6666-4666-8666-666666666666',
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    '66666666666666666666666666666666',
    decode(repeat('06', 32), 'hex'),
    'Legacy full owner',
    ARRAY[
      'projects.create',
      'projects.manage_access',
      'memory.write',
      'memory.read',
      'search.keyword',
      'members.manage',
      'teams.manage',
      'tokens.manage'
    ],
    FALSE,
    NOW(),
    NOW()
  );
""")

Ecto.Adapters.SQL.query!(Repo, """
UPDATE organization_memberships
SET deactivated_at = NOW(), updated_at = NOW()
WHERE user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
""")
