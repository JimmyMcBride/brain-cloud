#!/bin/sh
set -eu

partition="_phase2_upgrade"

for required_command in env mix; do
  command -v "$required_command" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$required_command" >&2
    exit 1
  }
done

cleanup() {
  run_mix ecto.drop --force --quiet >/dev/null 2>&1 || true
}

run_mix() {
  env -u DATABASE_URL PHASE2_UPGRADE=true MIX_ENV=test MIX_TEST_PARTITION="$partition" mix "$@"
}

trap cleanup EXIT

run_mix ecto.drop --force --quiet >/dev/null 2>&1 || true
run_mix ecto.create --quiet
run_mix ecto.migrate --to 20260728051000 --quiet

run_mix run scripts/phase2_upgrade_seed.exs

run_mix ecto.migrate --quiet

run_mix run scripts/phase2_upgrade_verify.exs
