#!/usr/bin/env python3
"""엄격한 순차 실행 watcher.

한 번에 하나의 issue 만 todo 상태로 두고, 그 issue 가 in_review / done 으로 전환되면
다음 task ID (T001 → T002 → ... → T405 의 task ID 정렬 순) 의 issue 를 todo 로 promotion.

오너 분포는 그대로 두되, claude-code 와 codex 가 자신의 차례에만 일하도록 보장한다.

사용:
    python3 scripts/multica-strict-sequential.py                # 1회 점검
    python3 scripts/multica-strict-sequential.py --watch         # 60초 간격 무한
    python3 scripts/multica-strict-sequential.py --reset-from T020  # 특정 task 부터 다시 시작
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time

PROJECT_ID = "b38cb695-5c18-4aaa-9d08-e948817824b7"
TODO_STATUSES = {"todo"}
ACTIVE_STATUSES = {"in_progress"}
DONE_STATUSES = {"in_review", "done"}


def run(args):
    res = subprocess.run(args, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"ERR: {' '.join(args)}\n{res.stderr}", file=sys.stderr)
        return None
    try:
        return json.loads(res.stdout)
    except json.JSONDecodeError:
        return None


def list_issues():
    out, offset = [], 0
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


TASK_RE = re.compile(r"^T(\d+)\s")


def task_id(issue) -> int | None:
    m = TASK_RE.search(issue.get("title", ""))
    if not m:
        return None
    return int(m.group(1))


def get_ordered_tasks(issues):
    todoable = []
    for i in issues:
        if i.get("title", "").startswith("[EPIC]"):
            continue
        tid = task_id(i)
        if tid is None:
            continue
        todoable.append((tid, i))
    return sorted(todoable, key=lambda x: x[0])


AGENT_BY_DIFFICULTY = {"L": "claude-code", "M": "claude-code", "H": "codex"}


def desired_agent(issue):
    labels = {l["name"] for l in issue.get("labels", [])}
    if "phase:setup" in labels or "phase:foundation" in labels:
        return "claude-code"
    if "phase:us1" in labels or "phase:us2" in labels or "phase:us3" in labels:
        return "codex"
    if "phase:hardening" in labels:
        title = issue.get("title", "")
        if "runbook" in title or "README" in title:
            return "claude-code"
        return "codex"
    return "claude-code"


def tick(issues, verbose=True):
    """홀딩 풀(cancelled)에서 task ID 순서대로 1개씩 todo 로 promotion."""
    ordered = get_ordered_tasks(issues)
    active = [i for _, i in ordered if i.get("status") in (TODO_STATUSES | ACTIVE_STATUSES)]
    done_or_review = [i for _, i in ordered if i.get("status") in DONE_STATUSES]
    holding = [i for _, i in ordered if i.get("status") in ("backlog", "cancelled")]
    if verbose:
        print(f"# active={len(active)} done/review={len(done_or_review)} holding={len(holding)}")
    if active:
        cur = active[0]
        if verbose:
            print(f"# current: {cur.get('identifier')} {cur.get('status')} {cur.get('title')[:60]}")
        return False
    if not holding:
        print("# 모든 task 처리 완료.")
        return True
    nxt = holding[0]
    agent = desired_agent(nxt)
    print(f"# promote {nxt.get('identifier')} → todo (assign:{agent}): {nxt.get('title')[:60]}")
    run(["multica", "issue", "status", nxt["id"], "todo", "--output", "table"])
    # 명시적 재할당: 직전 cancel-tasks 가 큐 row 까지 비웠을 수 있어서
    # unassign 후 다시 assign 하면 새 queue row 가 생성된다.
    run(["multica", "issue", "assign", nxt["id"], "--unassign"])
    run(["multica", "issue", "assign", nxt["id"], "--to", agent, "--output", "json"])
    # 안전망: 만약 assign 만으로 queue 가 생기지 않으면 rerun 으로 강제 enqueue
    run(["multica", "issue", "rerun", nxt["id"], "--output", "json"])
    return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--watch", action="store_true")
    p.add_argument("--interval", type=int, default=60)
    p.add_argument("--reset-from", help="task ID (e.g. T020) 부터 다시 시작")
    args = p.parse_args()

    if args.reset_from:
        m = re.match(r"T(\d+)", args.reset_from)
        if not m:
            print("invalid --reset-from", file=sys.stderr); return 1
        target_tid = int(m.group(1))
        issues = list_issues()
        for i in issues:
            if i.get("title","").startswith("[EPIC]"): continue
            tid = task_id(i)
            if tid is None: continue
            new_status = "todo" if tid == target_tid else "backlog"
            if i.get("status") != new_status:
                run(["multica","issue","status",i["id"],new_status,"--output","table"])
                print(f"  {i.get('identifier')} → {new_status}")
        return 0

    while True:
        issues = list_issues()
        finished = tick(issues)
        if finished or not args.watch:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
