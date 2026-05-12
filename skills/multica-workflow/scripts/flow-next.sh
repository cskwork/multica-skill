#!/usr/bin/env bash
# Thin wrapper: advance a ticket to the next phase.
# Delegates to bin/multica-flow next <id>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
exec "$ROOT/bin/multica-flow" next "$@"
