---
name: review
description: Review a pull request or diff — language-aware dispatcher. Detects which file types are changed and fans out to the right specialist skills automatically. Each specialist skill runs itself as an isolated subagent and determines its own diff scope, so the review doesn't inherit the implementing session's bias and never scans the whole repo. If any must-fix findings are found, AUTO-INVOKE review-loop to apply auto-fixable corrections and re-check. Triggers include "PR 리뷰해", "코드 리뷰해", "review this", "review my PR", "리뷰해줘". Replaces the default /review skill with a smarter routing layer.
version: 0.1.0
---

# review — language-aware PR review dispatcher

PR 리뷰를 요청하면 diff를 스캔해서 변경된 언어/프레임워크에 맞는 전문 스킬을 자동으로 실행합니다.  
사용자는 `/review` 하나만 알면 됩니다.

## Phase 1 — Enumerate changed files

현재 브랜치와 base 브랜치 사이의 diff를 수집합니다:

```sh
git diff --name-only $(git merge-base HEAD main)...HEAD
```

base 브랜치가 `main`이 아닐 수 있으므로 확인:
```sh
git remote show origin | grep "HEAD branch"
gh pr view --json baseRefName -q .baseRefName 2>/dev/null
```

파일 목록을 언어별로 분류합니다:

| 언어/프레임워크 | 패턴 |
|---|---|
| Java | `*.java` |
| Kotlin | `*.kt`, `*.kts` |
| TypeScript/React | `*.tsx`, `*.jsx` |
| TypeScript/NestJS | `*.ts` in `src/` with `@Module`, `@Controller`, `@Injectable` |
| Next.js | `*.tsx` under `app/` or `pages/` |

## Phase 2 — Run general PR review

모든 언어에 공통으로 먼저 일반 PR 리뷰를 수행합니다:

- PR title, description, scope 확인
- diff 크기 및 의도 파악
- 명백한 로직 오류, 하드코딩된 값, 보안 이슈 (SQL injection, XSS, secret 노출) 체크
- 테스트 커버리지 갭 확인

## Phase 3 — Language-specific dispatch (subagent)

Phase 1에서 감지된 파일 타입에 따라 아래 스킬을 `Skill` 도구로 호출합니다. 복수의 언어가 감지되면 모두 병렬로 호출합니다.

### Java / Kotlin 파일이 있는 경우 → jvm-memory-leak-review

`.java` 또는 `.kt` 파일이 diff에 포함되면 **반드시** 실행:

- Static 컬렉션 누적 패턴
- ThreadLocal remove() 누락
- Listener unregister 누락
- 무한 캐시 (TTL/크기 제한 없음)
- 미닫힌 리소스 (Stream, Connection, EntityManager)
- Bean scope 불일치 (singleton이 prototype 직접 주입)
- @Async / CompletableFuture 대형 객체 캡처

### Kotlin 파일이 있는 경우 → kotlin-coroutine-review

`.kt` 파일이 포함되면 실행:

- blocking call in suspend function
- GlobalScope / structured-concurrency 위반
- Dispatcher 오용 (IO vs Default)
- CoroutineExceptionHandler 누락
- Flow / Channel 백프레셔 문제

### Kafka listener가 있는 경우 → spring-kafka-listener-review

`@KafkaListener` 어노테이션이 diff에 포함되면 실행:

```sh
git diff $(git merge-base HEAD main)...HEAD | grep -l "@KafkaListener"
```

### React/Next.js 파일이 있는 경우 → react-hooks-review

`.tsx` / `.jsx` 파일이 포함되면 실행:

- useEffect dependency array 오류
- stale closure
- async effect cleanup 누락

### NestJS 파일이 있는 경우 → nestjs-provider-review

`.ts` 파일에서 `@Injectable`, `@Module`, `@Controller` 가 포함되면 실행.

## Phase 4 — Aggregate findings

각 subagent(forked skill)의 결과를 하나의 리포트로 합칩니다:

```
## PR Review — <브랜치명>

### General
<공통 리뷰 결과>

### JVM Memory Leak (jvm-memory-leak-review)
<findings or "발견 없음">

### Kotlin Coroutines (kotlin-coroutine-review)
<findings or "해당 없음 — Kotlin 파일 없음">

...
```

**must-fix** 항목이 하나라도 있으면 리포트 상단에 강조합니다.  
발견이 전혀 없으면 "전 항목 통과 — PR 머지 준비됨" 으로 명시합니다.

## Non-goals

- 이 스킬은 직접 코드를 수정하지 않습니다.
- PR을 자동으로 열거나 닫지 않습니다.
- 비즈니스 로직의 정확성 판단은 이 스킬 범위 밖입니다.
