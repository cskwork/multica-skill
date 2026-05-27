#!/usr/bin/env python3
"""순차 실행 세팅 스크립트.

동작:
- 모든 stuck(blocked/in_progress/in_review) 이슈를 todo 로 리셋한다.
- 1차 wave(phase:setup) 만 todo, 나머지(foundation/us1/us2/us3/hardening)는 backlog 로 옮긴다.
- 에이전트의 max_concurrent_tasks 를 1 로 낮춰 안전하게 순차 처리.
"""
from __future__ import annotations

import json
import subprocess
import sys

PROJECT_ID = "b38cb695-5c18-4aaa-9d08-e948817824b7"

WAVES = [
    "phase:setup",  # wave 0 (즉시 todo)
    "phase:foundation",
    "phase:us1",
    "phase:us2",
    "phase:us3",
    "phase:hardening",
]

ACTIVE_WAVE = "phase:setup"


def run(args, capture=True):
    res = subprocess.run(args, capture_output=capture, text=True)
    if res.returncode != 0:
        print(f"ERR: {' '.join(args)}\n{res.stderr}", file=sys.stderr)
        return None
    if capture and res.stdout.strip():
        try:
            return json.loads(res.stdout)
        except json.JSONDecodeError:
            return None
    return None


def list_issues():
    out = []
    offset = 0
    while True:
        data = run([
            "multica","issue","list","--project",PROJECT_ID,
            "--limit","100","--offset",str(offset),"--output","json"])
        if not data:
            break
        batch = data.get("issues", []) if isinstance(data, dict) else data
        if not batch:
            break
        out.extend(batch)
        if isinstance(data, dict) and data.get("has_more"):
            offset += len(batch)
        else:
            break
    return out


def main():
    issues = list_issues()
    print(f"# {len(issues)} issues fetched", file=sys.stderr)
    promoted = 0
    backlog = 0
    reset = 0
    for issue in issues:
        if issue["title"].startswith("[EPIC]"):
            continue
        labels = {l["name"] for l in issue.get("labels", [])}
        ident = issue.get("identifier")
        current = issue.get("status")

        # 1) 1차 wave (phase:setup) 는 todo 로 통일
        if ACTIVE_WAVE in labels:
            if current not in ("todo",):
                run(["multica","issue","status",issue["id"],"todo","--output","table"], capture=False)
                promoted += 1
                print(f"  [setup wave] {ident} {current} → todo")
            continue

        # 2) 나머지는 backlog 로 (자동 dispatch 방지)
        if current != "backlog":
            run(["multica","issue","status",issue["id"],"backlog","--output","table"], capture=False)
            if current in ("blocked","in_progress","in_review"):
                reset += 1
            else:
                backlog += 1
            print(f"  [holdback] {ident} {current} → backlog")
    print(f"# setup-promote={promoted} reset-from-stuck={reset} new-backlog={backlog}", file=sys.stderr)

    # 3) 에이전트 concurrency 1 로 제한
    for aid, name in [
        ("5f4bb832-06f3-43c2-8ccd-55524296df7d","claude-code"),
        ("c3129f9f-4534-4dbb-b28a-5f453f6aaff4","codex"),
    ]:
        run(["multica","agent","update",aid,"--max-concurrent-tasks","1","--output","json"], capture=False)
        print(f"  [agent] {name} max_concurrent_tasks=1")


if __name__ == "__main__":
    main()
