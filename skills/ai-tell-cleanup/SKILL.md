---
name: ai-tell-cleanup
description: Scan and fix AI writing tells in code comments, commit messages, and PR bodies — removes em dashes, over-explained comments that restate the code, filler phrases ("This ensures that", "Note that", "It is worth noting"), verbose docstrings, and section-separator noise. AUTO-INVOKE before any commit or PR creation, and when reviewing diffs that touch comments or documentation. Triggers include "ai 티 제거", "주석 정리", "comment cleanup", "ai 티 안나게", "too verbose", "clean up comments".
version: 0.1.0
---

# ai-tell-cleanup

AI가 생성한 코드나 텍스트에는 사람이 잘 쓰지 않는 패턴이 반복됩니다.  
이 스킬은 코드 주석, 커밋 메시지, PR 본문에서 그 패턴을 찾아내고 수정합니다.

## 대상 범위

- 소스 코드 인라인 주석 (`//`, `#`, `/* */`, `/** */`)
- 커밋 메시지 body
- PR title / body
- SKILL.md, README.md 같은 문서 파일

## Phase 1 — Em dash 및 특수 구두점

AI가 가장 자주 남기는 타이포그래픽 패턴입니다.

| 패턴 | 문제 | 처리 |
|---|---|---|
| `—` (em dash) | 한국어 문서, 영어 주석 모두에서 AI 특유 | `: ` 또는 `-`로 교체하거나 문장 재구성 |
| `…` (ellipsis 문자) | 일반 `...` 대신 유니코드 사용 | `...`으로 교체 |
| `"` `"` (curly quotes) | 코드 주석에서 스마트 따옴표 | `"` `"`로 교체 |

Grep 패턴:
```
—|…|"|"
```

## Phase 2 — 코드를 그대로 설명하는 주석

코드 자체가 이미 말하는 내용을 반복하는 주석은 제거합니다.

제거 대상 패턴:

```java
// 사용자를 ID로 조회한다
User user = userRepository.findById(id);

// 결과를 반환한다
return result;

// 리스트를 초기화한다
List<String> items = new ArrayList<>();
```

판단 기준: 주석을 지워도 코드를 이해하는 데 전혀 지장이 없으면 제거.

## Phase 3 — AI 필러 문구

주석이나 문서에서 정보 없이 길이만 늘리는 문구들입니다.

제거/축약 대상:

| 원문 | 처리 |
|---|---|
| `This ensures that ...` | 삭제하거나 내용만 남김 |
| `Note that ...` | 삭제 |
| `It is worth noting that ...` | 삭제 |
| `Please note that ...` | 삭제 |
| `In order to ...` | `To ...` 로 축약 |
| `The reason for this is ...` | 삭제하거나 직접 설명으로 교체 |
| `This method is responsible for ...` | 삭제 (메서드 이름이 이미 설명) |
| `We need to ...` | 삭제 |
| `As mentioned above ...` | 삭제 |
| `이를 통해 ...` | 삭제 |
| `위와 같이 ...` | 삭제 |
| `해당 ...` | 직접 지칭으로 교체 |

## Phase 4 — 과도한 섹션 구분 주석

코드 블록을 억지로 나누는 장식성 주석입니다.

제거 대상:
```java
// =====================
// User Management
// =====================

// --- Validation ---

// ########################################
// Step 1: Initialize
// ########################################
```

함수/클래스 분리로 구조를 표현해야 할 위치에 주석으로 때운 패턴입니다.  
주석을 제거하고 코드 구조 자체로 읽히도록 제안합니다.

## Phase 5 — 과도한 docstring / Javadoc

모든 파라미터, 반환값, 예외를 기계적으로 나열한 주석입니다.

제거 또는 축약 대상:

```java
/**
 * 사용자를 조회합니다.
 *
 * @param id 사용자 ID입니다. 이 값은 null이 아니어야 합니다.
 * @param name 사용자 이름입니다. 검색에 사용됩니다.
 * @return 조회된 User 객체를 반환합니다. 없으면 null을 반환합니다.
 * @throws IllegalArgumentException id가 null인 경우 발생합니다.
 */
User findUser(Long id, String name);
```

시그니처와 타입이 이미 말하는 내용의 반복입니다.  
WHY가 없는 docstring은 제거를 권장합니다. WHY가 있다면 한 줄로 요약합니다.

## Phase 6 — 커밋 메시지 패턴

커밋 메시지 body에서 AI 티 나는 패턴입니다.

| 패턴 | 처리 |
|---|---|
| `This commit ...` / `This PR ...` 로 시작하는 body | 삭제 (subject line이 이미 설명) |
| `Co-Authored-By: Claude` / `Generated with Claude Code` | 삭제 |
| 동사 없는 bullet 나열 ("Memory leak fix", "Refactoring") | 동사로 시작하도록 수정 |
| em dash가 포함된 bullet | `-` 또는 재구성 |

## Phase 7 — PR 본문 패턴

| 패턴 | 처리 |
|---|---|
| `🤖 Generated with Claude Code` footer | 삭제 |
| em dash (`—`) | 제거 또는 재구성 |
| `This PR introduces ...` / `This PR adds ...` 첫 문장 | 삭제하고 바로 내용으로 시작 |
| 5개 이상의 중첩 bullet | 평탄화 |
| `In this PR, we ...` | 삭제 |

## Phase 8 — Emit findings

각 발견 항목:

```
[<severity>] <category>: <한 줄 요약>
  Where: <파일>:<줄 번호> 또는 커밋/PR 위치
  Original: <원문>
  Fix: <수정안>
```

Severity 기준:
- **fix** — AI 티가 명확하게 남는 패턴 (em dash, AI 푸터, 코드 그대로 설명 주석)
- **consider** — 제거하면 더 깔끔하지만 판단이 필요한 경우

발견 후 사용자 확인 없이 자동 수정 가능한 항목 (em dash, AI 푸터)은 바로 수정합니다.  
코드 주석 제거처럼 의도 파악이 필요한 항목은 제안만 합니다.

## Non-goals

- 코드 로직은 건드리지 않습니다.
- 테스트 코드의 설명 주석은 문서 역할이므로 기준을 완화합니다.
- 외부 라이브러리 / 서드파티 코드는 스캔 제외합니다.
