# open-claude-all

[![npm](https://img.shields.io/npm/v/open-claude-all.svg)](https://www.npmjs.com/package/open-claude-all)
[![license](https://img.shields.io/npm/l/open-claude-all.svg)](LICENSE)

Claude Code가 코드를 잘 쓰는 건 기본입니다. 이 패키지는 그 다음 단계, **PR로 내보내기 전에 놓치는 것들**을 잡아줍니다.

- 리뷰어가 보기 전에 버그 패턴 미리 검출
- AI가 쓴 티 나는 주석과 문구 자동 정리
- protected 브랜치 직접 수정 차단
- PR 전 영향 범위 자동 파악

---

## 설치

```sh
npx open-claude-all
```

설치 후 Claude Code를 재시작하면 자동으로 스킬이 로드됩니다.

다른 설치 방법이 필요하다면:

| 방법 | 명령어 |
| --- | --- |
| Plugin marketplace | `/plugin marketplace add BK202503/open-claude-all` |
| curl | `curl -fsSL https://bk202503.github.io/open-claude-all/get \| bash` |
| Git clone | `git clone https://github.com/BK202503/open-claude-all.git ~/.open-claude-all && ~/.open-claude-all/install.sh` |

버전 고정: `npx open-claude-all@0.1.3`

---

## 스킬 목록

### PR 리뷰 파이프라인

`/review` 하나만 실행하면 아래 스킬들이 순서대로 자동 연결됩니다.

| 스킬 | 역할 |
| --- | --- |
| `review` | diff에서 언어를 감지해 해당 전문 스킬로 자동 라우팅. must-fix 발견 시 `review-loop` 자동 실행. |
| `review-loop` | 리뷰 후 확실한 항목(em dash, AI 푸터, 불필요 주석)만 자동 수정하고 재검토. 판단이 필요한 항목은 사람에게. |
| `ai-tell-cleanup` | 코드 주석, 커밋 메시지, PR 본문의 AI 특유 패턴 제거. 코드 수정 직후 자동 실행. `"ai-tell-cleanup 끄기"`로 비활성화 가능. |
| `pr-impact-scan` | PR 전 변경된 함수/클래스의 모든 호출부를 추적하고, 테스트 누락과 호환성 문제를 찾아 PR 본문 초안 작성. |

### Java / Kotlin

| 스킬 | 잡아주는 것 |
| --- | --- |
| `jvm-memory-leak-review` | static 컬렉션 누수, ThreadLocal 미해제, 리스너 미해제, 무제한 캐시, 미닫힌 리소스, 빈 스코프 불일치, @Async 공유 상태, Kotlin Channel/Flow 누수. `.java` / `.kt` 파일 diff 시 자동 실행. |
| `kotlin-coroutine-review` | suspend 함수 내 blocking 호출, GlobalScope 누수, Dispatcher 오용, CoroutineExceptionHandler 누락, Flow 역압 문제. |
| `spring-kafka-listener-review` | DefaultErrorHandler 설정 오류, @RetryableTopic 함정, ack 모드, DLT 미연결, suspend @KafkaListener 버전 호환성. |

### React / Next.js

| 스킬 | 잡아주는 것 |
| --- | --- |
| `react-hooks-review` | useEffect 의존성 배열 오류, stale closure, functional updater 누락, list key 안티패턴, async effect cleanup 누락. |
| `nextjs-app-router-review` | 서버/클라이언트 컴포넌트 경계 오류, fetch 캐시 설정 오류, Next 15+ async params, 서버 시크릿 클라이언트 번들 유출. |
| `frontend-perf-impact-scan` | 번들 크기 증가, LCP/CLS 위험, 네트워크 waterfall, hydration 불일치 — Blocker / Watch / Nit 등급으로 분류. |

### NestJS

| 스킬 | 잡아주는 것 |
| --- | --- |
| `nestjs-provider-review` | injection scope 오용, forwardRef로 숨겨진 순환 의존성, module exports 누락, 필터/인터셉터/파이프/가드 순서 문제. |

### 병렬 작업

독립적인 작업 여러 개를 동시에 처리할 때 씁니다.

| 스킬 | 언제 |
| --- | --- |
| `parallel-dev` | 코드 작성이 포함된 N개의 독립 작업. 각각 별도 git worktree에서 실행, 부모가 순서대로 머지. |
| `parallel-dispatch` | 읽기 전용 조회 N개 동시 실행 (PR 상태 확인, 로그 조회 등). worktree 없음, 빠름. |

### 안전

| 훅 | 역할 |
| --- | --- |
| `branch-guard` | main / master / trunk에 직접 파일 수정 시 PreToolUse 훅으로 차단. |

### 에이전트

스킬을 조합해 PR 단위로 한 번에 실행합니다.

| 에이전트 | 역할 |
| --- | --- |
| `pr-reviewer` | scope 점검, 영향 범위 파악, 커밋 스타일 검토를 한 번에. Blocker / Watch / Nit 등급 출력. |
| `pr-impact-runner` | PR URL을 받아 `pr-impact-scan`을 실행하고 요약 리포트 반환. |

---

## 설정

`branch-guard` 동작은 환경 변수로 조정합니다 (모두 선택 사항).

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `WW_PROTECTED_BRANCHES` | `main,master,trunk` | 차단할 브랜치 목록 |
| `WW_ALLOW_MAIN_WRITE=1` | 꺼짐 | 임시 우회 (CI, 설정 스크립트용) |
| `WW_STRICT=1` | 꺼짐 | 엄격 모드: 브랜치 불명확 시 차단 |
| `WW_STRICT_ALLOWLIST` | `$HOME/.claude:/tmp:/var/tmp` | 엄격 모드에서도 허용할 경로 |

---

## 요구 사항

- Claude Code v2.1 이상
- `jq` (훅 연결용. 없으면 설치 시 수동 안내로 대체)

## 제거

```sh
~/.open-claude-all/uninstall.sh
```

이 패키지가 설치한 것만 제거합니다. 직접 만든 스킬과 훅은 건드리지 않습니다.

## 기여

PR은 `dev` 브랜치로 보내주세요. 자세한 규칙은 [`CONTRIBUTING.md`](CONTRIBUTING.md)를 참고하세요.

## 라이선스

MIT. `LICENSE` 파일 참조.
