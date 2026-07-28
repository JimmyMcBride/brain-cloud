#!/bin/sh
set -eu

/app/bin/brain_cloud eval 'BrainCloud.Release.migrate()'
exec /app/bin/brain_cloud start
