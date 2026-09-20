# RepFlow — Claude 작업 지침

> 푸시업/풀업 전용 iOS + watchOS 앱. GTG (Grease the Groove) 모드 + 인터벌 트레이너 + 워치 자동 카운트.

---

## ⚠️ 작업 시작 전 필독

**모든 작업은 코드가 아닌 [SPEC.md](./SPEC.md) 에서 시작한다.**

- 새 세션이 열리면 가장 먼저 `SPEC.md` 를 **전체** 읽는다.
- `SPEC.md §0 (Status)` 로 현재 버전 / 알고리즘 / 미해결 항목을 파악한다.
- 사용자의 요청이 `SPEC.md §0` 의 미해결 항목과 일치하는지 확인한다.
- 코드를 보기 **전에** SPEC의 관련 절을 먼저 읽고 컨텍스트를 잡는다.

이 규칙은 새 세션 / 컴팩션 직후 / 새 Claude 인스턴스 모두에 동일하게 적용된다.
SPEC.md만 보면 직전 세션이 어디서 멈췄는지, 다음에 무엇을 해야 하는지 알 수 있어야 한다.

---

## ⚠️ 작업 종료 전 필수

코드를 변경했다면 **반드시** `SPEC.md` 의 해당 절을 동시에 갱신한다.
규약과 갱신 대상 절은 `SPEC.md §13 (SPEC 유지 프로토콜)` 참조.

영향 절 매핑 요약:
- 알고리즘 변경 → §4 + `RepDetectorAlgorithm.current` 증가
- 데이터 모델 / UserDefaults → §3
- Watch UI 상태 / 레이아웃 → §5
- 메시지 키 / 액션 / 이벤트 → §6
- 빌드 구성 / 배포 → §9
- 새로운 함정 발견 → §12에 한 줄 추가

가능하면 같은 커밋에 SPEC 변경을 포함한다 (git history ↔ SPEC 동기 유지).

---

## 코드 컨벤션

- **Protocol-First**: 새 서비스는 `Domain/Protocols/` (iOS) 또는 `Shared/` 에 프로토콜 먼저 정의
- **에러 타입**: 서비스마다 `Error: LocalizedError` enum, 한국어 `errorDescription`
- **ViewModel/Coordinator**: `@Observable final class`
- **하드코딩 금지**: 사용자 메시지는 `errorDescription` 통해
- **워치 ↔ 폰 통신**: `WatchMessageKey` 상수 사용, 직접 문자열 금지
- **Shared/ 제약**: iOS와 watchOS 양쪽에서 컴파일되므로 `UIKit` / `WatchKit` import 금지. 허용: `Foundation`, `SwiftUI`, `CoreMotion`

## 네이밍

- Protocol: `{Name}Protocol`
- Service: `{Name}Service`
- View: `{Feature}View` (iOS는 `RepFlow/Presentation/Views/`, 워치는 `RepFlowWatch/Views/`)

## 빌드 / 배포 (간단 명령)

```bash
xcodegen generate                                          # project.yml 변경 후
xcodebuild -scheme RepFlow -project RepFlow.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
fastlane beta                                              # TestFlight 업로드
```

상세 절차 / Fastfile 동작 / 함정은 `SPEC.md §9` 참조.

- Bundle ID: `com.digimaru.repflow` / `com.digimaru.repflow.watch`
- Team: KUDC7C6Z9H
- 최소 iOS 17.0 / watchOS 10.0

---

## 문서 규약 이탈 (의도적)

하우스 표준(`/Volumes/SSD/DEV_SSD/MY/_meta/AppCommonSkill/02-methodology-spec-first.md`)은
`spec/00-…15-` 번호 트리지만, RepFlow는 단일 `SPEC.md` 를 쓴다. §0 상태 스냅샷 + §13 갱신
프로토콜로 이미 세이브게임 역할을 하고 있어 16개 파일로 쪼개는 건 순수 churn이라고 판단했다.
**새 문서를 만들지 말고 `SPEC.md` 를 갱신할 것.**

## 관련 문서

- **[SPEC.md](./SPEC.md)** — 현재 상태의 단일 진실 (작업 시작점) ⭐
- [README.md](./README.md) — 외부 사용자 대상 소개
- [DESIGN.md](./DESIGN.md) — 디자인 시안 / 와이어프레임
- [ASO.md](./ASO.md) — 앱스토어 최적화 메타데이터
