#!/usr/bin/env python3
"""Wave promoter: 현재 wave 가 모두 in_review/done 이면 다음 wave 를 todo 로 promotion.

사용:
    python3 scripts/multica-wave-promote.py        # 1회 점검 + 가능 시 promotion
    python3 scripts/multica-wave-promote.py --watch  # 60초 간격 무한 점검
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time

PROJECT_ID = "b38cb695-5c18-4aaa-9d08-e948817824b7"
WAVES = [
    "phase:setup",
    "phase:foundation",
    "phase:us1",
    "phase:us2",
    "phase:us3",
    "phase:hardening",
]
COMPLETED = {"in_review", "done"}
PENDING = {"todo", "in_progress", "blocked"}


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


def find_active_wave(issues):
    for wave in WAVES:
        members = [i for i in issues if any(l["name"]==wave for l in i.get("labels", []))]
        if not members:
            continue
        statuses = {i.get("status") for i in members}
        if statuses & PENDING:
            return wave, members
        if statuses <= COMPLETED:
            continue
    return None, []


def promote_next_wave(issues, current):
    idx = WAVES.index(current)
    if idx + 1 >= len(WAVES):
        return None
    nxt = WAVES[idx + 1]
    targets = [i for i in issues if any(l["name"]==nxt for l in i.get("labels", []))
               and i.get("status") == "backlog"]
    for i in targets:
        run(["multica","issue","status",i["id"],"todo","--output","table"])
        print(f"  promoted {i.get('identifier')} → todo")
    return nxt if targets else None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--watch", action="store_true")
    p.add_argument("--interval", type=int, default=60)
    args = p.parse_args()

    while True:
        issues = list_issues()
        wave, members = find_active_wave(issues)
        if wave is None:
            print("# 모든 wave 완료. 정리할 backlog 없음.")
            break
        statuses = {}
        for m in members:
            statuses[m.get("status","?")] = statuses.get(m.get("status","?"),0)+1
        print(f"# active wave: {wave} {statuses}")
        if all(m.get("status") in COMPLETED for m in members):
            promoted = promote_next_wave(issues, wave)
            if promoted:
                print(f"# advanced to {promoted}")
            else:
                print("# no next wave to promote")
                break
        if not args.watch:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
