#!/usr/bin/env python3
"""Multica 이슈 owner 를 정책에 맞게 재정렬하는 스크립트.

정책 (사용자 직접 지시):
- SETUP phase (label phase:setup)        → claude-code (infra/repo/skeleton/ADR)
- FOUND phase (label phase:foundation)   → claude-code (DB / 도메인 / infra setup)
- US1/US2/US3 phase                      → codex (테스트 + 구현)
- HARDENING:
    - 제목에 `runbook` 또는 `README` 포함 → claude-code
    - 그 외 (DataPolicyFilter, EvalGatekeeper, eval runner, CI 파이프라인) → codex
"""
from __future__ import annotations

import json
import subprocess
import sys

PROJECT_ID = "b38cb695-5c18-4aaa-9d08-e948817824b7"


def desired_owner(labels: list[str], title: str) -> str:
    if "phase:setup" in labels or "phase:foundation" in labels:
        return "claude-code"
    if "phase:us1" in labels or "phase:us2" in labels or "phase:us3" in labels:
        return "codex"
    if "phase:hardening" in labels:
        if "runbook" in title or "README" in title:
            return "claude-code"
        return "codex"
    return "claude-code"


def run_json(args: list[str]) -> dict | list | None:
    res = subprocess.run(args, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"ERROR: {' '.join(args)}\n{res.stderr}", file=sys.stderr)
        return None
    if not res.stdout.strip():
        return None
    try:
        return json.loads(res.stdout)
    except json.JSONDecodeError:
        return None


def list_issues() -> list[dict]:
    issues = []
    offset = 0
    while True:
        data = run_json(
            [
                "multica",
                "issue",
                "list",
                "--project",
                PROJECT_ID,
                "--limit",
                "100",
                "--offset",
                str(offset),
                "--output",
                "json",
            ]
        )
        if not data:
            break
        batch = data.get("issues", []) if isinstance(data, dict) else data
        if not batch:
            break
        issues.extend(batch)
        if isinstance(data, dict) and data.get("has_more"):
            offset += len(batch)
        else:
            break
    return issues


AGENT_NAMES = {
    "5f4bb832-06f3-43c2-8ccd-55524296df7d": "claude-code",
    "c3129f9f-4534-4dbb-b28a-5f453f6aaff4": "codex",
}


def main() -> int:
    issues = list_issues()
    print(f"# fetched {len(issues)} issues", file=sys.stderr)

    moved = 0
    for issue in issues:
        if issue["title"].startswith("[EPIC]"):
            continue
        labels = [l["name"] for l in issue.get("labels", [])]
        title = issue["title"]
        want = desired_owner(labels, title)
        current = AGENT_NAMES.get(issue.get("assignee_id") or "", "")
        if current == want:
            continue
        identifier = issue.get("identifier")
        result = run_json(
            [
                "multica",
                "issue",
                "assign",
                issue["id"],
                "--to",
                want,
                "--output",
                "json",
            ]
        )
        if result is not None:
            moved += 1
            print(f"  → {identifier} {title[:75]} : {current or '-'} → {want}")
    print(f"# moved {moved} issues", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
