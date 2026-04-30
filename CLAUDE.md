# RepFlow

> 푸시업/풀업 전용 iOS + watchOS 앱. GTG (Grease the Groove) 모드 + 인터벌 트레이너 + 워치 자동 카운트.

## 아키텍처

```
RepFlow/             — iOS 앱
  App/               — RepFlowApp (entry)
  Domain/Models/     — SwiftData 모델 (WorkoutSession, GTGDay, UserProfile)
  Services/          — GTGSchedulerService, HealthKitService, PhoneSessionService, PersistenceService
  Presentation/      — SwiftUI Views (Dashboard, Programs, History, Settings, GTGSettings)

RepFlowWatch/        — watchOS 앱
  App/               — RepFlowWatchApp + WatchCoordinator (@Observable)
  Services/          — WatchSessionService (WCSession)
  Views/             — Menu, WorkoutLive, IntervalRun, GTGQuick

Shared/              — 양 타깃에서 사용 (iOS 타겟·watchOS 타겟 모두 컴파일됨)
  WatchMessage.swift           — ExerciseKind, WorkoutMode, WatchAction, PhoneEvent, 메시지 키
  IntervalProgram.swift        — IntervalProgram, IntervalState
  RepDetectorProtocol/Service  — CoreMotion 기반 rep 자동 카운트
  IntervalTimerProtocol/Service — Timer 기반 EMOM/Tabata/AMRAP
```

## 핵심 차별점

**GTG (Grease the Groove)** — 시장에 비어있는 자리. 푸시업/풀업 진보의 검증된 훈련법.
- 하루 N개 알림을 startHour~endHour 사이 균등 분포 + 지터로 스케줄
- 매 알림마다 일일 목표 / N 만큼 추천. 절대 한계까지 가지 않음 (RPE 5).
- `GTGSchedulerService`가 `UNCalendarNotificationTrigger`로 로컬 알림 예약
- 워치는 알림이 올 때 빠르게 `GTGQuickView`로 진입해 자동 카운트 시작

## 규칙

### 코드 컨벤션
- **Protocol-First**: 새 서비스는 `Domain/Protocols/` (iOS) 또는 Shared/에 프로토콜 먼저 정의
- **에러 타입**: 서비스마다 `Error: LocalizedError` enum, 한국어 `errorDescription`
- **ViewModel/Coordinator**: `@Observable final class`
- **하드코딩 금지**: 사용자 메시지는 `errorDescription` 통해
- **워치 ↔ 폰 통신**: `WatchMessageKey` 상수 사용, 직접 문자열 금지

### 네이밍
- Protocol: `{Name}Protocol`
- Service: `{Name}Service`
- View: `{Feature}View`
- Watch View: `{Feature}View` (in `RepFlowWatch/Views/`)

### 빌드 & 배포
```bash
# 프로젝트 재생성 (project.yml 변경 시)
xcodegen generate

# 시뮬레이터 빌드
xcodebuild -scheme RepFlow -project RepFlow.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# TestFlight
AUTO_INCREMENT_BUILD_NUMBER=true fastlane beta
```
- Bundle ID: `com.digimaru.repflow` / `com.digimaru.repflow.watch`
- Team: KUDC7C6Z9H
- 최소 iOS 17.0 / watchOS 10.0

### 과거 교훈
- **xcodegen + entitlements**: `entitlements.properties:`에 키를 넣으면 xcodegen이 파일을 생성/덮어씀. 빈 `<dict/>` 스타일 entitlements는 path만 지정.
- **HealthKit 엔타이틀먼트**: `com.apple.developer.healthkit.access`는 verifiable health records 용으로 Apple 별도 승인 필요. v1에서는 entitlement 자체를 빼고 v1.1에서 (1) ASC App ID에 HealthKit capability 활성화 (2) entitlement 추가.
- **Shared 코드**: iOS와 watchOS 양 타깃에서 컴파일되므로 platform-specific API (`UIKit`, `WatchKit`)는 사용 불가. CoreMotion, Foundation, SwiftUI 만 OK.
- **Bundle ID 충돌**: `com.repflow.app`은 ASC에서 이미 등록됨. 본인 prefix 사용 (`com.digimaru.*`).
