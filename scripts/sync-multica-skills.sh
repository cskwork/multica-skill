#!/usr/bin/env bash
set -euo pipefail

SOURCE_WORKSPACE_ID="${SOURCE_WORKSPACE_ID:-}"
TARGET_WORKSPACE_ID="${TARGET_WORKSPACE_ID:-}"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/sync-multica-skills.sh [--source-workspace-id ID] [--target-workspace-id ID] [--dry-run]

Environment overrides:
  SOURCE_WORKSPACE_ID=...
  TARGET_WORKSPACE_ID=...

Example:
  SOURCE_WORKSPACE_ID=src-workspace-id TARGET_WORKSPACE_ID=dst-workspace-id scripts/sync-multica-skills.sh

Behavior:
  - Copies every skill from source workspace to target workspace.
  - Matches target skills by name.
  - Creates missing skills.
  - Updates existing skill description, content, and config.
  - Upserts attached skill files when present.
  - Does not delete target-only skills or target-only files.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-workspace-id)
      SOURCE_WORKSPACE_ID="${2:?missing source workspace id}"
      shift 2
      ;;
    --target-workspace-id)
      TARGET_WORKSPACE_ID="${2:?missing target workspace id}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_cmd multica
require_cmd jq

if [[ -z "$SOURCE_WORKSPACE_ID" || -z "$TARGET_WORKSPACE_ID" ]]; then
  echo "Both source and target workspace IDs are required." >&2
  echo "Run 'multica workspace list' to find workspace IDs." >&2
  usage >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

source_list="$tmp_dir/source-skills.json"
target_list="$tmp_dir/target-skills.json"

echo "Source workspace: $SOURCE_WORKSPACE_ID"
echo "Target workspace: $TARGET_WORKSPACE_ID"

multica --workspace-id "$SOURCE_WORKSPACE_ID" skill list --output json >"$source_list"
multica --workspace-id "$TARGET_WORKSPACE_ID" skill list --output json >"$target_list"

source_count="$(jq 'length' "$source_list")"
target_count="$(jq 'length' "$target_list")"
echo "Source skills: $source_count"
echo "Target skills before sync: $target_count"

jq -r '.[] | [.id, .name] | @tsv' "$source_list" | while IFS=$'\t' read -r source_id source_name; do
  source_skill="$tmp_dir/source-$source_id.json"
  multica --workspace-id "$SOURCE_WORKSPACE_ID" skill get "$source_id" --output json >"$source_skill"

  description="$(jq -r '.description // ""' "$source_skill")"
  content="$(jq -r '.content // ""' "$source_skill")"
  config="$(jq -c '.config // {}' "$source_skill")"
  target_id="$(jq -r --arg name "$source_name" '.[] | select(.name == $name) | .id' "$target_list" | head -n 1)"

  if [[ -z "$target_id" ]]; then
    echo "CREATE $source_name"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      created="$(
        multica --workspace-id "$TARGET_WORKSPACE_ID" skill create \
          --name "$source_name" \
          --description "$description" \
          --content "$content" \
          --config "$config" \
          --output json
      )"
      target_id="$(jq -r '.id' <<<"$created")"
    fi
  else
    echo "UPDATE $source_name"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      multica --workspace-id "$TARGET_WORKSPACE_ID" skill update "$target_id" \
        --name "$source_name" \
        --description "$description" \
        --content "$content" \
        --config "$config" \
        --output json >/dev/null
    fi
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    jq -c '.files[]?' "$source_skill" | while IFS= read -r file_json; do
      path="$(jq -r '.path' <<<"$file_json")"
      file_content="$(jq -r '.content // ""' <<<"$file_json")"
      echo "  UPSERT FILE $source_name/$path"
      multica --workspace-id "$TARGET_WORKSPACE_ID" skill files upsert "$target_id" \
        --path "$path" \
        --content "$file_content" \
        --output json >/dev/null
    done
  fi
done

if [[ "$DRY_RUN" -eq 0 ]]; then
  multica --workspace-id "$TARGET_WORKSPACE_ID" skill list --output json >"$target_list"
fi

echo "Target skills after sync: $(jq 'length' "$target_list")"
