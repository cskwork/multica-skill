#!/usr/bin/env python3
"""tasks.md → Multica 이슈 일괄 등록 스크립트.

가정:
- 현재 multica CLI 가 Item-OS workspace 에 인증되어 있다.
- claude-code / codex 에이전트가 등록되어 있다.
- 프로젝트와 라벨이 미리 생성되어 있다.

사용:
    python3 scripts/multica-import-tasks.py \
        --tasks specs/001-twin-question-platform/tasks.md \
        --project b38cb695-5c18-4aaa-9d08-e948817824b7 \
        --epic 91df944c-0f0f-4941-b897-9e08127267da \
        [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass

LABEL_IDS = {
    "phase:setup": "d88843a1-e3bb-48ab-926e-83129366022e",
    "phase:foundation": "74b136f3-aca1-47d1-9f81-ac1c439b8967",
    "phase:us1": "baac4d0c-b791-4b9f-a7be-fcf66a98462a",
    "phase:us2": "079701c8-f76c-4070-ae39-9c57a511c88d",
    "phase:us3": "604f39f5-9d7c-45b6-b93c-82c3f156aeda",
    "phase:hardening": "22ad98bc-34f0-40e9-97f7-2d029475fe31",
    "difficulty:L": "e7989bf9-8e99-48f9-8f71-9d0684ae87a2",
    "difficulty:M": "58da2607-529d-4e88-940c-809d210f8c1d",
    "difficulty:H": "02e2a13c-8bc0-4978-9288-d13fcf7577c6",
    "subject:math": "ce9a7bf2-7675-4519-876e-55f235f12846",
    "tdd:tests-first": "0f1e9b62-da23-45e3-a167-34469987dab0",
}

STORY_LABEL = {
    "SETUP": "phase:setup",
    "FOUND": "phase:foundation",
    "US1": "phase:us1",
    "US2": "phase:us2",
    "US3": "phase:us3",
}

OWNER_BY_DIFFICULTY = {"L": "claude-code", "M": "claude-code", "H": "codex"}
PRIORITY_BY_DIFFICULTY = {"L": "low", "M": "medium", "H": "high"}


@dataclass
class Task:
    tid: str
    parallel: bool
    story: str
    difficulty: str
    owner_hint: str
    title: str
    section_phase: str  # heading-derived (overrides story-only when present)
    is_test: bool  # 테스트 task 인지 (TDD label)


TASK_LINE = re.compile(
    r"^- \[ \] (?P<tid>T\d+)\s+(?P<flags>(?:\[[^\]]+\]\s*)+)\s*(?P<rest>.*)$"
)


def parse_tasks(path: str) -> list[Task]:
    tasks: list[Task] = []
    current_phase = "SETUP"
    in_test_block = False
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            heading = re.match(r"^## Phase \d+: (.+)$", line)
            if heading:
                title = heading.group(1)
                if "Setup" in title and "Shared" in title:
                    current_phase = "SETUP"
                elif "Setup" in title and "인프라" in title:
                    current_phase = "SETUP"
                elif "Foundational" in title:
                    current_phase = "FOUND"
                elif "User Story 1" in title:
                    current_phase = "US1"
                elif "User Story 2" in title:
                    current_phase = "US2"
                elif "User Story 3" in title:
                    current_phase = "US3"
                elif "Hardening" in title:
                    current_phase = "HARDENING"
                elif "Research" in title:
                    current_phase = "SETUP"
                in_test_block = False
                continue
            if re.match(r"^### Tests for", line):
                in_test_block = True
                continue
            if re.match(r"^### Implementation", line):
                in_test_block = False
                continue

            match = TASK_LINE.match(line)
            if not match:
                continue
            tid = match.group("tid")
            flags_str = match.group("flags")
            rest = match.group("rest").strip()
            flags = [f.strip("[] ").strip() for f in re.findall(r"\[([^\]]+)\]", flags_str)]

            parallel = "P" in flags
            story = next(
                (f for f in flags if f in ("SETUP", "FOUND", "US1", "US2", "US3")),
                current_phase if current_phase != "HARDENING" else "HARDENING",
            )
            difficulty = next((f for f in flags if f in ("L", "M", "H")), "M")
            owner_hint = next(
                (f for f in flags if f in ("claude-code", "codex")),
                OWNER_BY_DIFFICULTY[difficulty],
            )
            tasks.append(
                Task(
                    tid=tid,
                    parallel=parallel,
                    story=story,
                    difficulty=difficulty,
                    owner_hint=owner_hint,
                    title=rest,
                    section_phase=current_phase,
                    is_test=in_test_block,
                )
            )
    return tasks


def run(args: list[str], dry_run: bool, capture: bool = True) -> dict | None:
    if dry_run:
        print(" ".join(args))
        return None
    res = subprocess.run(args, capture_output=capture, text=True)
    if res.returncode != 0:
        print(f"ERROR: {' '.join(args)}\n{res.stderr}", file=sys.stderr)
        sys.exit(2)
    if capture and res.stdout.strip():
        try:
            return json.loads(res.stdout)
        except json.JSONDecodeError:
            return None
    return None


def label_ids_for(task: Task) -> list[str]:
    ids = [LABEL_IDS["subject:math"]]
    if task.section_phase == "HARDENING":
        ids.append(LABEL_IDS["phase:hardening"])
    else:
        story_label = STORY_LABEL.get(task.story)
        if story_label:
            ids.append(LABEL_IDS[story_label])
    ids.append(LABEL_IDS[f"difficulty:{task.difficulty}"])
    if task.is_test:
        ids.append(LABEL_IDS["tdd:tests-first"])
    return ids


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--tasks", required=True)
    p.add_argument("--project", required=True)
    p.add_argument("--epic", required=True)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--limit", type=int, default=0, help="0 means all tasks")
    p.add_argument("--skip", type=int, default=0)
    p.add_argument("--no-assign", action="store_true", help="라벨만 붙이고 assignee 는 건너뜀")
    args = p.parse_args()

    tasks = parse_tasks(args.tasks)
    if args.skip:
        tasks = tasks[args.skip :]
    if args.limit:
        tasks = tasks[: args.limit]
    print(f"# {len(tasks)} 개 task 등록 예정", file=sys.stderr)

    for t in tasks:
        title = f"{t.tid} [{t.story}] {t.title}"
        if len(title) > 200:
            title = title[:197] + "..."

        body_lines = [
            f"## Task {t.tid}",
            "",
            f"- Story: {t.story}",
            f"- Phase: {t.section_phase}",
            f"- Difficulty: {t.difficulty} (정책상 owner 권고: {t.owner_hint})",
            f"- Parallel friendly: {'yes' if t.parallel else 'no'}",
            f"- TDD test task: {'yes' if t.is_test else 'no'}",
            "",
            "### 상세",
            t.title,
            "",
            "### 참고 문서",
            "- 사양: `specs/001-twin-question-platform/spec.md`",
            "- 설계: `specs/001-twin-question-platform/plan.md`",
            "- 데이터 모델: `specs/001-twin-question-platform/data-model.md`",
            "- Contracts: `specs/001-twin-question-platform/contracts/`",
            "",
            "### 정의된 작업 규칙",
            "- branch: `feat/<MULTICA-ID>-<slug>` (테스트 only 일 경우 `test/<MULTICA-ID>-<slug>`).",
            "- TDD: 테스트가 먼저 실패한 뒤 구현. validator 영향 시 eval 재실행.",
            "- 헌법 v1.0.0 (.specify/memory/constitution.md) 준수.",
        ]
        body = "\n".join(body_lines)

        priority = PRIORITY_BY_DIFFICULTY[t.difficulty]
        create_args = [
            "multica",
            "issue",
            "create",
            "--title",
            title,
            "--priority",
            priority,
            "--project",
            args.project,
            "--parent",
            args.epic,
            "--description",
            body,
            "--output",
            "json",
        ]
        resp = run(create_args, dry_run=args.dry_run)
        if args.dry_run or resp is None:
            continue
        issue_id = resp["id"]
        identifier = resp.get("identifier", issue_id)
        print(f"{identifier} {t.tid} {title[:80]}")

        for lid in label_ids_for(t):
            run(
                [
                    "multica",
                    "issue",
                    "label",
                    "add",
                    issue_id,
                    lid,
                    "--output",
                    "table",
                ],
                dry_run=False,
                capture=True,
            )

        if not args.no_assign:
            run(
                [
                    "multica",
                    "issue",
                    "assign",
                    issue_id,
                    "--to",
                    t.owner_hint,
                    "--output",
                    "json",
                ],
                dry_run=False,
                capture=True,
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
