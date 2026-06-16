# multica-skill

**한국어 · [English](README.en.md)**

[Multica](https://cskwork.github.io/multica-skill/) 관리형 에이전트 플랫폼을 위한
**하네스 비종속 단일 [Agent Skill](https://agentskills.io)**. 어떤 코딩 에이전트에게든
**전체 `multica` CLI**, **머신 온보딩 방법**, 그리고 Multica 보드 위에서 돌리는
**다단계 코딩 파이프라인**(explore → work → review → qa → learn)을 가르칩니다.

> 스킬 하나. CLI 전체. 온보딩과 워크플로우를 공식 문서에 맞춰 담았습니다.

📄 **랜딩 페이지:** [cskwork.github.io/multica-skill](https://cskwork.github.io/multica-skill/)

---

## 구성

스킬은 하나이며, 무거운 세부 내용은 references로 분리했습니다(progressive disclosure —
에이전트는 필요한 파일만 읽습니다):

| 파일 | 용도 |
|------|------|
| `skills/multica/SKILL.md` | 레퍼런스 카드: 멘탈 모델, 명령어 인덱스, Multica를 움직이는 3대 규칙. |
| `skills/multica/references/cli-reference.md` | 영역별 전체 CLI 명령어와 정확한 플래그. |
| `skills/multica/references/onboarding.md` | 첫 실행: 설치 → `setup` → 런타임 확인 → 에이전트 생성 → 첫 작업. |
| `skills/multica/references/workflow.md` | explore→work→review→qa→learn 파이프라인, rewind 로직, 복사용 셸 레시피. |

모든 명령어는 Multica 공식 `CLI_AND_DAEMON.md`와 `docs/cli`에 1:1로 대조했습니다 — 추측 플래그 없음.

---

## 설치

### 방법 1 — Multica 경유 (권장)

```bash
multica skill import --url https://github.com/cskwork/multica-skill
multica skill list | grep multica
multica agent skills <agent-slug>      # 에이전트에 부착 (중첩 명령 — --help 참고)
```

### 방법 2 — 다른 하네스

```bash
git clone https://github.com/cskwork/multica-skill ~/.multica-skill
cd ~/.multica-skill
./install.sh                 # claude / codex / gemini / opencode / pi 자동 감지
# 또는 하나만 지정:
./install.sh claude-code     # → ~/.claude/skills/multica/
```

이후 하네스 안에서 `/multica`를 호출하거나 "multica"를 언급하면 스킬이 로드됩니다.

---

## 파이프라인

Multica의 상태는 고정(`backlog | todo | in_progress | in_review | done | blocked |
cancelled`)이고 라벨 설정 CLI 명령이 없습니다. 그래서 워크플로우는 각 단계를
**이슈 메타데이터**(`pipeline_status`)에 기록하고, 상태를 옮기며 재할당해 진행합니다:

```
explore ─▶ work ─▶ review ─▶ qa ─▶ learn ─▶ done
   ▲                  │        │
   └──── rewind ◀──────┴────────┘     review나 qa에서 문제 발견 → work로 되돌림
```

각 단계는 새 컨텍스트 에이전트가 실행하며, review/qa 실패 시 하나의 긴 세션을 오염시키는
대신 `work`로 rewind합니다. QA 3회 연속 실패 → `blocked` + 사람 구독자 호출. 전체 상태
다이어그램과 바로 실행 가능한 `advance.sh` / `rewind.sh` 스니펫은
[`skills/multica/references/workflow.md`](skills/multica/references/workflow.md)에 있습니다.

---

## 빠른 맛보기

```bash
# 티켓 생성 → 탐색 시작 → 데몬이 에이전트를 디스패치
ID=$(multica issue create --title "Add CSV export to /reports" --priority high \
       | grep -oE 'MUL-[0-9]+' | head -1)
multica issue metadata set "$ID" --key pipeline_status --value explore
multica issue assign "$ID" --to claude-explorer

# 진행 관찰
multica issue get "$ID"
multica daemon logs
```

---

## 하네스 호환성

| 하네스 | 스킬 경로 | 어댑터 |
|--------|-----------|--------|
| Multica (네이티브) | `multica skill import` | 불필요 — 1급 지원 |
| Claude Code | `~/.claude/skills/multica/` | `adapters/claude-code.sh` |
| Codex CLI | `~/.codex/skills/` + `~/.codex/commands/multica.md` | `adapters/codex.sh` |
| Gemini CLI | gemini 확장 | `adapters/gemini.sh` |
| OpenCode | `~/.config/opencode/skills/multica/` | `adapters/opencode.sh` |
| Pi | `~/.pi/skills/multica/` | `adapters/pi.sh` |

---

## 레포 구조

```
multica-skill/
├── skills/multica/
│   ├── SKILL.md
│   └── references/
│       ├── cli-reference.md
│       ├── onboarding.md
│       └── workflow.md
├── adapters/              # 하네스별 설치 스크립트 (단일 스킬)
├── docs/index.html        # GitHub Pages 랜딩
├── install.sh
└── LICENSE
```

### 랜딩 페이지 게시

랜딩은 `docs/index.html` 단일 self-contained 파일입니다. 게시하려면:
**Settings → Pages → Build from a branch → `main` / `/docs`**. 그러면
`https://<owner>.github.io/multica-skill/`에서 서비스됩니다.

---

## 라이선스

MIT. [LICENSE](LICENSE) 참고.

## 크레딧

- 파이프라인 형태는 [cskwork/symphony-multi-agent](https://github.com/cskwork/symphony-multi-agent)에서 이식.
- [Multica](https://multica.ai) — 오픈소스 관리형 에이전트 플랫폼 — 을 위해 제작.
