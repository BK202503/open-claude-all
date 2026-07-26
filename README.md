# open-claude-all

Claude Code 에서 **PR 을 깔끔하게 올리고 기존 코드에 대한 임팩트를 미리 검증** 하는 데 초점 맞춘 skill / hook 모음.

## Why use this

기본 Claude Code 는 코드 잘 씀. 하지만 그 코드가 **PR 로 나가기 직전** 필요한 두 가지는 놓치기 쉬움:

1. **PR 이 깔끔한가**. 스코프가 흐트러졌거나, 커밋 메시지가 diff 를 재진술만 하거나, 상관없는 리팩터가 섞였거나
2. **기존 코드에 무엇을 건드리는가**. 시그니처 바뀐 함수의 모든 caller, 이름 바뀐 config key 의 모든 참조, N+1 회귀, 이미 알려진 회귀 패턴 등

이 리포지토리는 그 두 축을 자동화함:

- **(A) 깔끔한 PR**. 스코프 discipline, 리뷰 문턱 낮추는 커밋 스타일, protected-branch 직접 쓰기 차단
- **(B) 기존 코드 임팩트 검증**. `pr-impact-scan` 으로 caller / test / config 블라인드 스팟 열거, 도메인별 review skill (Spring Kafka listener, Kotlin coroutine) 로 이미 알려진 회귀 패턴 사전 차단

경쟁 프레임워크 (oh-my-claudecode, claude-forge 등) 는 대부분 "코드 짜기" 자동화 (agent orchestration, prompt injection 등) 에 집중. 이 프로젝트는 **"짠 코드를 PR 로 안전하게 내보내기"** 라는 뒷단에 특화.

## 무엇이 들어있나

### Impact & PR quality (범용)

- `pr-impact-scan`: 변경된 함수 / 클래스 / config 키의 모든 caller 열거, 시그니처 호환성 판정, 테스트 커버리지 delta, PR body 초안
- `parallel-dispatch`: 병렬 read (status / lookup) fan-out
- `parallel-dev`: worktree 격리 병렬 개발 (write)
- `branch-guard`: `main` / `master` / `trunk` 직접 쓰기 차단 (backing PreToolUse hook 포함)

### Kotlin / JVM Spring track

- `spring-kafka-listener-review`: `DefaultErrorHandler`, `@RetryableTopic`, ack mode, DLT 배선, suspend `@KafkaListener` 버전 gap 등 이미 알려진 회귀 패턴 사전 차단
- `kotlin-coroutine-review`: structured concurrency 위반, blocking-in-suspend, dispatcher 오용, `GlobalScope` 누수, `CoroutineExceptionHandler` 누락 등

## Install

가장 가벼운 방법 (Node 18+ 필요):

```sh
npx open-claude-all
```

옵션:
- `npx open-claude-all --dry-run`: 실제 파일 안 만들고 뭐가 일어날지만 출력
- `npx open-claude-all --skip-hook`: skill 만 설치, `branch-guard` hook 배선 생략
- `npx open-claude-all uninstall`: 되돌리기

Node 없이 쓰고 싶으면 clone 후 스크립트 직접 실행:

```sh
git clone https://github.com/BK202503/open-claude-all.git ~/.open-claude-all
~/.open-claude-all/install.sh
```

Claude Code 세션 재시작 후 `/status` 로 skill 인식 확인.

## Requires

- Claude Code v2.1+ (skill / hook 지원)
- `jq` (hook 배선에만 사용, 없으면 배선만 건너뛰고 수동 안내 출력)

## Configure (환경변수, 전부 optional)

- `WW_PROTECTED_BRANCHES`: `branch-guard` 가 막을 브랜치. Default `main,master,trunk`
- `WW_ALLOW_MAIN_WRITE=1`: `branch-guard` 임시 우회 (CI / 셋업 스크립트용)

## Uninstall

```sh
~/.open-claude-all/uninstall.sh
```

이 스크립트는 이 repo 가 설치한 항목만 지움. 사용자가 직접 만든 skill / hook 은 건드리지 않음.

## Design principles

- **Read-only fan-out is safe; write fan-out needs isolation.** `parallel-dispatch` 는 read; `parallel-dev` 는 worktree 격리로 write.
- **Scope discipline.** 한 PR / 커밋에 여러 관심사 섞지 않음. `pr-impact-scan` 이 이 규율을 강제.
- **Impact-first review.** 코드 짜기보다 짠 코드가 뭘 건드리는지 이해가 먼저.
- **Never write on protected branches.** `branch-guard` hook 이 `main` / `master` / `trunk` 에서의 파일 편집을 차단.

## Non-goals

- Claude Code core 재구현 / 대체
- Multi-agent orchestration framework
- 모든 언어의 build / test wrapper. 프로젝트 자체 명령을 그대로 사용
- 인터랙티브 오케스트레이션 UI

## Contributing

PR 은 `dev` 브랜치 대상. 상세 규칙은 [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT. See `LICENSE`.
