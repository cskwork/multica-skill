#!/usr/bin/env bash
# Thin wrapper: rewind a ticket to phase:work after review/QA failure.
# Delegates to bin/multica-flow rewind <id>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$ROOT/bin/multica-flow" rewind "$@"
