---
name: jvm-memory-leak-review
description: Review Java/Kotlin (Spring Boot) code before PR for JVM memory leak patterns — static collection accumulation, ThreadLocal not removed, listener not unregistered, unbounded caches, unclosed resources, @Async-scoped shared state, and bean-lifecycle reference escapes. Triggers include "메모리 릭 검사해", "review for memory leak", "check this for OOM", "heap keeps growing", "GC keeps running".
version: 0.1.0
---

# jvm-memory-leak-review

GC가 있어도 참조를 잘못 관리하면 메모리 릭이 발생합니다. PR 전에 아래 패턴들을 구조적으로 검사합니다.

## Prerequisites

- 대상 파일 또는 모듈이 레포에 존재해야 합니다.
- Spring Boot를 사용하는 경우 `pom.xml` / `build.gradle` 가 보여야 합니다.
- Kotlin 코드라면 `kotlinx-coroutines` 버전을 확인합니다.

## Phase 1 — Static collection accumulation

Static 필드에 컬렉션을 두고 `put`/`add`만 하고 `remove`를 안 하면 애플리케이션 종료 전까지 객체가 해제되지 않습니다.

확인 항목:
- `static Map` / `static List` / `static Set` 에 데이터를 추가만 하고 제거 로직이 없는 패턴
- `companion object` 안의 `MutableMap` / `MutableList` (Kotlin)
- TTL/크기 제한 없이 사용하는 `HashMap`, `ArrayList` 캐시
- Caffeine, Guava Cache, Redis 같은 bounded 캐시 대신 naked 컬렉션을 캐시로 쓰는 경우

Grep 대상:
```
static.*Map<
static.*List<
static.*Set<
companion object.*Map
```

## Phase 2 — ThreadLocal leak

ThreadPool 환경에서 `ThreadLocal`을 `remove()` 없이 두면 Thread가 살아 있는 한 값도 살아 있습니다.  
Spring의 `@Async`, Tomcat 스레드풀, Netty EventLoop 모두 해당됩니다.

확인 항목:
- `ThreadLocal.set(...)` 이후 `try/finally` + `remove()` 패턴이 없는 경우
- `InheritableThreadLocal` 을 자식 스레드에 전파한 뒤 정리 안 함
- `RequestContextHolder`, `SecurityContextHolder` 를 수동으로 set한 뒤 clear 없음

Grep 대상:
```
ThreadLocal<
\.set(
\.remove()   # remove()가 없는 쪽 찾기
```

## Phase 3 — Listener / callback not unregistered

이벤트 버스나 pub-sub 구조에서 `register` 후 `unregister`를 빠뜨리면 listener 객체가 계속 참조됩니다.

확인 항목:
- `eventBus.register(...)` / `eventBus.post(...)` 쌍에서 `unregister` 없음 (Guava EventBus 등)
- `applicationContext.addApplicationListener(...)` 후 제거 없음
- `MessageListenerContainer.addMessageListener(...)` 후 제거 없음
- Spring의 `@EventListener` 빈이 prototype scope일 때 — singleton EventMulticaster가 prototype 빈을 참조하여 절대 GC 안 됨
- Kotlin 코루틴 `Flow.collect` / `stateIn` 구독 후 Job 취소 없음

## Phase 4 — Unbounded cache

캐시에 TTL이나 최대 크기가 없으면 Heap은 계속 증가합니다.

확인 항목:
- `ConcurrentHashMap` 을 캐시처럼 사용하면서 eviction 정책 없음
- `@Cacheable` + `CacheManager` 설정에서 `maximumSize` / `expireAfterWrite` 없음
- `spring.cache.caffeine.spec` 미설정 상태에서 Caffeine 사용
- Guava `CacheBuilder` 에서 `.maximumSize()` / `.expireAfterWrite()` 미설정
- Redis 캐시에 `@Cacheable(cacheNames=..., unless=...)` 만 있고 TTL 설정 없음

## Phase 5 — Unclosed resources

`close()` 를 명시적으로 호출하지 않거나 `try-with-resources` / `use { }` 밖에서 리소스를 열면 누수됩니다.

확인 항목:
- `InputStream` / `OutputStream` / `Connection` / `PreparedStatement` 를 `try-with-resources` 또는 Kotlin `use { }` 없이 사용
- `EntityManager` 를 직접 `createEntityManager()` 로 열고 `close()` 없음
- `RestTemplate` / `WebClient` 응답 body를 소비하지 않고 버림 (특히 streaming response)
- `Files.lines(path)` 반환 `Stream<String>` 을 `use { }` 없이 사용

## Phase 6 — Spring bean lifecycle & scope mismatch

짧은 lifecycle의 빈이 긴 lifecycle 빈에 주입되면 짧은 빈이 절대 해제되지 않습니다.

확인 항목:
- singleton 빈이 prototype 빈을 필드로 주입받는 경우 — prototype이 singleton처럼 동작
- `@RequestScope` / `@SessionScope` 빈이 singleton에 직접 주입되는 경우 (프록시 없이)
- `ApplicationContext` 자체를 static 필드에 보관하고 getBean으로 꺼내 쓰는 패턴
- `@PreDestroy` / `DisposableBean.destroy()` 없이 외부 리소스(커넥션, 스케줄러)를 보유한 빈

## Phase 7 — @Async / CompletableFuture shared state

비동기 작업이 shared mutable 상태를 참조하면 작업이 완료될 때까지 해당 객체가 해제되지 않습니다.

확인 항목:
- `@Async` 메서드의 파라미터로 대용량 도메인 객체를 통째로 넘기는 경우 (작업 큐에 쌓이면 Heap 증가)
- `CompletableFuture.supplyAsync(...)` 람다 안에서 outer scope의 컬렉션을 캡처
- `@Scheduled` 작업이 결과를 static 필드에 누적하며 초기화 없음
- Kotlin `launch { ... }` 가 outer scope의 대형 객체를 클로저로 캡처한 채 장시간 실행

## Phase 8 — Kotlin-specific: Channel / Flow

- `Channel(UNLIMITED)` 또는 `Channel(Int.MAX_VALUE)` — 소비자가 느리면 메모리 무한 증가
- `MutableSharedFlow(replay = Int.MAX_VALUE)` — 모든 과거 값을 메모리에 보관
- `callbackFlow { ... }` 에서 `awaitClose { }` 미구현 — 구독 해제 시 리소스 정리 안 됨
- `GlobalScope.launch { ... }` 로 생성된 Job — 취소 수단 없이 Heap 계속 참조

## Phase 9 — Emit findings

각 발견 항목은 아래 형식으로 출력합니다:

```
[<severity>] <category>: <한 줄 요약>
  Where: <파일>:<줄 번호>
  Why it matters: <영향 한 문장>
  Fix: <구체적인 코드 변경 또는 설정>
  Reference: <관련 문서 / 이슈 링크 있으면 포함>
```

Severity 기준:
- **must-fix** — OOM 직결, GC 불가, 리소스 고갈
- **should-fix** — 장기 실행 시 Heap 증가, GC 부담, 운영 위험
- **consider** — 잠재적 누수 가능성, 코드 패턴 개선

must-fix 먼저 정렬. 발견 없으면 "발견된 메모리 릭 패턴 없음" 으로 명시 — 억지로 만들어내지 않음.

## Non-goals

- Heap dump 분석 및 실제 메모리 측정은 이 스킬 범위 밖입니다 (jmap, JFR, MAT 도구 필요).
- GC 튜닝 파라미터 (`-Xmx`, GC 알고리즘) 권고는 하지 않습니다.
- 코드를 직접 수정하지 않습니다. 발견 사항을 보고하고 수정은 사용자가 결정합니다.
