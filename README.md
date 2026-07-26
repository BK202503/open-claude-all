# open-claude-all

Claude Code에서 **업스트림 OSS 컨트리뷰션 워크플로우**를 첫 클래스로 지원하는 skill / agent / hook 모음.

찾기 → 패치 → 제출 → 상태 추적. 각 단계를 한 커맨드로.

- `oss-survey` — unclaimed bug 발굴, 프로베넌스 제시
- `oss-contribute` — clone → patch → test → PR draft (승인 전 push / comment 없음)
- `oss-status-sweep` — 여러 PR 상태 병렬 조회 → 우선순위 정렬
- `oss-pr-status` (agent) — 단일 PR / 이슈 / 커밋 스냅샷
- `oss-router` (agent) — OSS phase 자동 라우팅

부수적으로 개발 자체를 안전하고 빠르게:

- `parallel-dev` — worktree 격리 병렬 개발 (write)
- `parallel-dispatch` — 병렬 조회 (read)
- `branch-guard` — `main` / `master` / `trunk` 직접 쓰기 차단 hook

## Install

```sh
git clone https://github.com/<owner>/open-claude-all.git ~/.open-claude-all
~/.open-claude-all/install.sh
```

옵션:
- `--dry-run` — 실제 파일 안 만들고 뭐가 일어날지만 출력
- `--skip-hook` — skill / agent 만 설치, `branch-guard` hook 배선 생략

Claude Code 세션 재시작 후 `/status` 로 skill 인식 확인.

## Requires

- Claude Code v2.1+ (skill / hook 지원)
- `gh` CLI 인증 (OSS 워크플로우용)
- `jq` (hook 배선에만 사용 — 없으면 배선 스텝만 건너뛰고 수동 안내 출력)

## Configure (환경변수, 전부 optional)

- `OSS_WORK_ROOT` — clone 위치. Default `~/oss-work`
- `OSS_SWEEP_TARGETS` / `OSS_SWEEP_TARGETS_FILE` — 상태 스윕 대상 URL 목록 (개행 구분)
- `WW_PROTECTED_BRANCHES` — `branch-guard` 가 막을 브랜치. Default `main,master,trunk`
- `WW_ALLOW_MAIN_WRITE=1` — `branch-guard` 임시 우회 (CI / 셋업 스크립트용)

## Uninstall

```sh
~/.open-claude-all/uninstall.sh
```

이 스크립트는 이 repo가 설치한 항목만 지움 — 사용자가 직접 만든 skill / agent / hook 은 건드리지 않음.

## Design principles

- **User-approval gates on every upstream-visible action.** 업스트림 코멘트 / PR 생성 / PR 클로즈 등은 반드시 드래프트 → 사용자 승인 → 실행 순서. 자동 실행 금지.
- **Read-only fan-out is safe; write fan-out needs isolation.** `parallel-dispatch` 는 read; `parallel-dev` 는 worktree 격리로 write.
- **Scope discipline.** 한 PR / 커밋에 여러 관심사 섞지 않음. `oss-contribute` 는 이 규율을 강제.
- **Provenance over invention.** `oss-survey` 는 근거를 명시하며, 후보가 없으면 없다고 말함 (허구 후보 만들지 않음).

## Non-goals

- Claude Code core 재구현
- 모든 언어의 build / test wrapper — 프로젝트 자체 명령을 그대로 사용
- 인터랙티브 오케스트레이션 UI

## License

MIT. See `LICENSE`.
