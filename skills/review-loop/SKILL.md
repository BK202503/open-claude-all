---
name: review-loop
description: Iterative review-fix-recheck loop — runs the review skill, auto-fixes only deterministic findings (em dashes, AI footers, curly quotes, code-restating comments), re-runs review, repeats until clean or max 5 iterations. Stops and reports anything that needs human judgment. Triggers include "리뷰 루프 돌려", "review loop", "고치고 다시 확인", "자동 수정하고 재검토", "clean this up".
version: 0.1.0
---

# review-loop

리뷰에서 발견한 것 중 확실한 것들만 자동 수정하고, 다시 리뷰를 돌립니다.
판단이 필요한 항목은 사람에게 넘깁니다.

## 자동 수정 가능 목록 (auto-fixable)

아래 항목만 자동 수정합니다. 나머지는 전부 사람에게 넘깁니다.

| 카테고리 | 패턴 | 수정 방식 |
|---|---|---|
| `em-dash` | `—` in comments, strings, docs | `:` 또는 `-` 로 교체 |
| `curly-quote` | `"` `"` in comments | `"` `"` 로 교체 |
| `ellipsis-char` | `…` in comments | `...` 으로 교체 |
| `ai-footer` | `🤖 Generated with Claude Code` | 줄 전체 삭제 |
| `ai-footer` | `Co-Authored-By: Claude` | 줄 전체 삭제 |
| `section-separator` | `// ===...===`, `// ---...---`, `// ###...###` 3줄 블록 | 블록 전체 삭제 |
| `code-restating-comment` | 바로 다음 줄과 1:1 대응되는 주석 | 주석 줄 삭제 |

**자동 수정 하지 않는 것:**
- 로직, 알고리즘 변경
- 필러 문구 (Note that, This ensures that 등) — 문장 구조 판단 필요
- Javadoc 축약 — WHY 존재 여부 판단 필요
- 변수명, 함수명 변경

## Phase 1 — 대상 파일 수집

```sh
git diff --name-only $(git merge-base HEAD main)...HEAD
```

변경된 파일 목록을 수집합니다. 리뷰 대상은 이 파일들로 한정합니다.

## Phase 2 — 초기 리뷰 실행

`review` 스킬을 실행해 전체 findings를 수집합니다.

findings를 두 버킷으로 분류합니다:

- **auto-fixable**: 위 목록에 해당하는 항목 (severity: fix)
- **needs-human**: 나머지 전부 (severity: consider, 로직 관련, 판단 필요)

auto-fixable이 0개면 Phase 5로 바로 이동합니다.

## Phase 3 — 자동 수정 실행

auto-fixable 항목을 파일별로 묶어 순서대로 수정합니다.

수정 원칙:
- 한 파일씩 처리합니다. 여러 패턴이 같은 파일에 있으면 한 번에 수정합니다.
- 수정 전 원본 내용을 메모리에 보관합니다 (롤백 대비).
- 각 수정 후 `[수정] <파일>:<줄> — <원문> → <수정안>` 형식으로 로그를 남깁니다.

## Phase 4 — 재검토 루프

수정 완료 후 Phase 2로 돌아갑니다.

**종료 조건:**
- auto-fixable findings가 0개 → 루프 종료
- 반복 횟수가 5회 도달 → 루프 강제 종료, 남은 항목 리포트

5회 제한은 무한루프 방지를 위한 안전장치입니다.
정상적인 코드베이스라면 1-2회 안에 클린 상태가 됩니다.

## Phase 5 — 최종 리포트

```
## review-loop 결과

반복 횟수: N회
자동 수정 항목: M개

### 수정 내역
[수정] <파일>:<줄> — <원문> → <수정안>
...

### 사람이 확인해야 할 항목 (자동 수정 안 함)
[<severity>] <category>: <요약>
  Where: <파일>:<줄>
  Why: <이유>
  Fix 제안: <제안>
...

### 결과
클린 (auto-fixable 0개) | 5회 초과로 중단 — N개 잔여
```

needs-human 항목이 있으면 목록을 그대로 출력합니다.
없으면 "자동 수정 완료 — 잔여 이슈 없음" 을 출력합니다.

## Non-goals

- 로직, 비즈니스 코드를 변경하지 않습니다.
- 테스트를 실행하지 않습니다.
- 커밋은 하지 않습니다. 수정 후 사용자가 직접 커밋합니다.
- `review-loop` 자체가 PR을 열거나 닫지 않습니다.
