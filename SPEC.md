# RepFlow — Specification (Source of Truth)

> 새 세션이 시작될 때 가장 먼저 이 파일을 읽고 현재 상태를 파악한다.
> 모든 작업의 시작점은 코드가 아닌 이 SPEC. 작업 종료 시 반드시 본 문서를 갱신한다.
> 코드를 수정했다면 그 변경이 SPEC의 어느 절에 영향을 주는지 확인하고 동시에 업데이트하라.

---

## 0. 한눈에 보는 현재 상태 (Status @ 2026-09-20)

| 항목 | 값 |
|---|---|
| 마케팅 버전 | **1.0.3** (배포 시 1.0.4로 bump 예정) |
| 빌드 번호 | **11** 배포됨 / **12** 미배포 (탭 카운트 주력화 + 코어 루프 수리) |
| 입력 모델 | **탭 카운트 + 크라운 회전** (기본) / **모션 자동 감지** (실험적 opt-in) |
| 알고리즘 버전 | RepDetectorAlgorithm v3 — 자동 감지 켰을 때만 동작 |
| 최소 OS | iOS 17.0 / watchOS 10.0 |
| 번들 ID | `com.digimaru.repflow` (iOS) / `com.digimaru.repflow.watch` (watch) |
| 팀 ID | KUDC7C6Z9H |
| 메인 브랜치 | `main` |
| 마지막 커밋 | `d6f7e9d feat: rep 자동 카운트 알고리즘 v3 — 가속도+자이로 fusion + adaptive baseline` |

### 전략 전환 (2026-06-01)
- 워치 단독 모션 카운트(특히 푸시업)는 손목 가속도 진폭이 노이즈와 겹치는 본질적 한계. Apple Fitness도 미해결.
- **방향**: 워치는 **탭/크라운 카운트** 주력, 자동 감지는 실험 옵션. 폰 카메라(Vision)는 Pro로 후속.

### 방향 전환 (2026-09-20) — 「푸시업 100」

히어로 서사를 **"한 세트 100개"** 로 재포지셔닝한다. GTG·인터벌은 매니아용이라 검색 수요가 얕지만
"푸시업 100개"는 목표·검색어·완료 조건이 모두 명확하다. 종목 5종은 그대로 두고(자유 카운트),
**100개 프로그램과 카메라 카운트만 푸시업 전용**으로 한다.

계획 문서: `~/.claude/plans/purrfect-soaring-starlight.md` (M1~M8).

### 미해결 / 대기 항목

**M1 (코어 루프 수리) — 완료 @ 2026-09-20**
- ✅ 워치 운동 기록 SwiftData 영속화 (`WorkoutIngestService`) — 이전까지 저장 경로가 아예 없었다
- ✅ `didReceiveUserInfo` 구현 + 수신 단일 디스패처 (§6.5)
- ✅ 보장 송신 + `messageId` 중복 제거 (§6.4)
- ✅ 개인최고(`pushUpBest` 등)가 실제 운동으로 갱신되도록 수정 — 이전까지 설정 화면 스테퍼로만 바뀌었다
- ✅ `RepFlowTests` 실동작화 (이전까지 0바이트 빈 디렉터리)
- ✅ 리포 위생: `*.mobileprovision`/`*.p12`/`*.xcodeproj` gitignore, `xcodeVersion` 27.0
- 🔲 **실기기 검증 필요** — 워치 운동 → 폰 기록 반영, 비행기모드 폴백 경로

**M2 (100 프로그램 도메인) — 완료 @ 2026-09-20**
- ✅ `Shared/PushUpProgram.swift` — 레벨·사다리·진행 판정. 순수 Foundation이라 워치에서도 컴파일된다 (§14)
- ✅ 재측정 주간은 진행 판정에서 제외 — 세트가 하나뿐이라 매번 미달이 적립되고 있었다
- ✅ 테스트 총 56개 통과 (iOS) / watchOS 빌드 통과

**M3 (iOS 프로그램 UI) — 완료 @ 2026-09-20**
- ✅ `Shared/ProgramSessionRunner.swift` — 세션 진행 상태머신. **폰과 워치가 같은 것을 쓴다**(§14.6)
- ✅ `ProgramEnrollment` (@Model) — 훈련최대·주차·이력·이월 상태 영속화 (§14.7)
- ✅ `ProgramsView` → 100 프로그램 허브 (인터벌은 아래로 강등). 탭 이름도 "푸시업 100"
- ✅ `MaxTestView` (최대 측정 / 재측정) · `ProgramSessionView` (세션 진행)
- ✅ 스크린샷 자동화 훅: `UI_TESTING_TAB=n` / `UI_TESTING_ROUTE=session|maxTest` (§9.5)
- 시뮬레이터 실행으로 허브·세션 화면 확인 완료

**M4 (워치 프로그램) — 완료 @ 2026-09-20**
- ✅ `RepFlowWatch/Views/ProgramRunView.swift` — 폰과 **같은** `ProgramSessionRunner` 사용
- ✅ `WatchCoordinator.Screen.program(...)` + `MenuView` 최상단 진입점
- ✅ 메시지 프로토콜 확장 (§6.1 `programSessionCompleted` / §6.2 `programUpdated`)
- ✅ 폰이 다음 세션을 `updateApplicationContext` 로 미리 밀어 **워치 단독 완주** 가능
- 🔲 **실기기 검증 필요** — 폰 없이 완주 → 폰 기록·주차 반영, Health 저장

**M5·M6 (자동 카운트 + 음성) — 스캐폴딩 완료 @ 2026-09-21, 튜닝은 실기기 과제**
- ✅ `Shared/DepthRepDetector.swift` — 깊이 신호 rep 판정 (순수, 합성 신호 13종 테스트)
- ✅ `Shared/PoseGeometry.swift` — 관절 → 깊이·폼 점수 (순수, Vision import 없음)
- ✅ `Shared/PlacementCheck.swift` — 거치 게이트 (순수, 3초 연속 조건)
- ✅ `CameraRepCounter`(AVCapture + Vision) · `ProximityRepCounter` · `SpeechCounter`
- ✅ `PlacementGuideView` — 카메라 모드는 이 게이트를 통과해야 시작된다
- ✅ 세션 화면에 카운트 3종 전환 + 음성 카운트 아웃 + 휴식 카운트다운
- 🔲 **실기기 튜닝 필수** (§14.8) — 시뮬레이터에서는 카메라·근접센서 모두 검증 불가

**다음 (M7)** — 리브랜딩 · ASO 4언어 · 스크린샷 · TestFlight → 출시.
그 전에 실기기 검증(M1 워치 왕복 / M4 워치 단독 완주 / M5 기준 영상 튜닝)이 선행돼야 한다.

**이후**
- M3 iOS 프로그램 UI + 최대 측정 · M4 워치 프로그램 진행 화면
- M5 **폰 카메라 모드 (Vision / VNDetectHumanBodyPoseRequest)** — 거치 가이드 필수(정측면 1.5~2m), 폼 점수
- M6 음성 카운트 · 근접센서 모드 · 휴식 타이머
- M7 리브랜딩 · ASO · 출시 (README/ASO의 "워치 모션 자동 카운트" 헤드라인 제거 필수)
- M8 (출시 후) Live Activity · App Intent · 고스트 레이스


---

## 1. 제품 개요

**RepFlow** — 푸시업/풀업 전용 iOS + watchOS 앱.

핵심 차별점 3개:
1. **GTG (Grease the Groove)** — 시장에 빈 자리. 하루 동안 적은 양을 분산 시행해 신경계를 적응시키는 검증된 훈련법. RPE 5 상한.
2. **인터벌 트레이너** — EMOM / Tabata / AMRAP 모드. 코드 기반: `IntervalProgram`, `IntervalTimerService`.
3. **워치 자동 카운트** — CoreMotion 기반 rep detection. 폰 미사용 — 워치 단독 동작 + HKWorkoutSession 으로 백그라운드 보장.

수익 모델: **Pro 구독** (StoreKit 2). 월/년/평생. GTG 모드 + 인텔리전트 인터벌이 Pro 기능. ID: `com.digimaru.repflow.pro.{monthly|yearly|lifetime}`.

---

## 2. 디렉토리 / 모듈 구조

```
RepFlow/             — iOS 앱
  App/RepFlowApp.swift                   — @main entry, PhoneSessionService 활성화
  Domain/Models/                         — SwiftData (@Model)
    WorkoutSession.swift                 — 세션 + 세트 (1:N)
    GTGSession.swift                     — GTGDay + GTGPrompt (1:N)
    UserProfile.swift                    — 사용자 1RM/GTG 설정
  Domain/Protocols/                      — 인터페이스
    GTGSchedulerProtocol.swift
    HealthKitServiceProtocol.swift
  Services/
    PersistenceService.swift             — ModelContainer (SwiftData)
    PhoneSessionService.swift            — WCSession (iPhone side) + 누적 세션 카운트
    GTGSchedulerService.swift            — UNCalendarNotificationTrigger 스케줄러
    HealthKitService.swift               — iOS 측 HKWorkoutBuilder 저장
    ProManager.swift                     — StoreKit 2 구독 관리
    ReviewPromptService.swift            — SKStoreReviewController 트리거 (5/15/40/100)
    MockDataLoader.swift                 — UI 테스트 mock 주입
  Presentation/
    Components/Theme.swift               — RFColor / RFSpace / RFRadius / RFCard (Linear 영감)
    Views/                               — Dashboard, Programs, History, Settings,
                                           GTGSettings, CalibrationGuide, Paywall,
                                           Onboarding, QuickStartDetail, Root
  Resources/
    Info.plist                           — CFBundleVersion=11
    RepFlow.entitlements                 — HealthKit (key: com.apple.developer.healthkit)
    Assets.xcassets                      — AppIcon + 5개 운동 픽토그램
    {en,ko,ja,zh-Hans}.lproj             — 4언어 로컬라이제이션
    RepFlow.storekit                     — StoreKit 테스트 config

RepFlowWatch/        — watchOS 앱
  App/
    RepFlowWatchApp.swift                — @main entry, WatchSessionService.activate()
    WatchCoordinator.swift               — @Observable, Screen enum 라우터,
                                           RepDetectorService / IntervalTimerService 보유
  Services/
    WatchSessionService.swift            — WCSession (watch side) + GTG 프롬프트 큐
    WatchWorkoutManager.swift            — HKWorkoutSession 라이프사이클
  Views/
    RootWatchView.swift                  — Screen switch
    ProgramRunView.swift                 — 「푸시업 100」 세션 (폰과 동일한 ProgramSessionRunner)
    MenuView.swift                       — 운동 종목 + 인터벌 + 캘리브레이션 진입
    WorkoutLiveView.swift                — freeCount 모드 실시간 카운트
    IntervalRunView.swift                — EMOM/Tabata/AMRAP 인터벌
    GTGQuickView.swift                   — GTG 알림 응답 빠른 화면
    CalibrationView.swift                — 5회 측정 + 실시간 신호 bar
  Resources/
    Info.plist                           — CFBundleVersion=11, WKBackgroundModes=[workout-processing]
    RepFlowWatch.entitlements
    Assets.xcassets                      — AppIcon 단독

Shared/              — 양쪽 컴파일됨 (UIKit/WatchKit 사용 불가)
  WatchMessage.swift                     — ExerciseKind, WorkoutMode, WatchAction,
                                           PhoneEvent, WatchMessageKey, 픽토그램
  WatchPayload.swift                     — [String: Any] → 타입 있는 값 파싱 (순수 Foundation,
                                           WCSession 의존 없음 → 단독 테스트)
  PushUpProgram.swift                    — 100개 프로그램: PushUpLevel / SessionKind /
                                           ProgramLadder / ProgressionRule (순수 Foundation, §14)
  DepthRepDetector.swift                 — 0~1 깊이 신호 → rep (순수, §14.8)
  PoseGeometry.swift                     — 관절 → 깊이·폼 점수 (순수, Vision import 없음)
  PlacementCheck.swift                   — 카메라 거치 판정 + 3초 게이트 (순수)
  ProgramSessionRunner.swift             — 세션 진행 상태머신. 폰·워치 공용, 시계 주입 (§14.6)
  IntervalProgram.swift                  — IntervalProgram, IntervalState
  IntervalTimerProtocol.swift / Service  — Timer 기반 인터벌 엔진
  RepDetectorProtocol.swift              — UserCalibration / CalibrationStore /
                                           RepDetectorAlgorithm.current = 3
  RepDetectorService.swift               — CoreMotion 50Hz, gravity projection +
                                           gyro fusion + zero-crossing

RepFlowTests/        — Swift Testing. 파싱 / 영속화 / 중복 제거 / 100 프로그램 /
                       워치 왕복 / 깊이 판정 / 자세 기하 / 거치 게이트 (134 tests)
fastlane/Fastfile    — lanes: beta, test, upload_metadata
                       (ASC API key는 외부 경로: BurnCoach 디렉토리의 .p8)
project.yml          — XcodeGen 정의 (Signing=Automatic, healthkit entitlement true)
```

---

## 3. 데이터 모델 (SwiftData)

`PersistenceService.swift` 의 schema:

```swift
Schema([
  WorkoutSession.self,     // 세션 (1개) → WorkoutSet (N개)
  WorkoutSet.self,
  GTGDay.self,             // 하루 (1개) → GTGPrompt (N개)
  GTGPrompt.self,
  UserProfile.self         // 싱글톤 — RootView가 .ensureProfile()로 보장
])
```

### `WorkoutSession`
- `id`, `startedAt`, `endedAt?`, `exerciseRaw`, `modeRaw`, `totalReps`, `avgTempoSeconds`, `rpe?`, `notes?`
- `sets: [WorkoutSet]` (`.cascade`)

### `GTGDay`
- `id`, `date` (startOfDay), `exerciseRaw`, `targetReps` (예 50), `promptCount` (예 10), `dailyMaxRPE` (예 5)
- `prompts: [GTGPrompt]`
- 파생: `completedReps`, `progressRatio`

### `UserProfile` (싱글톤)
- `displayName`, `pushUpBest/pullUpBest/dipBest`
- GTG 설정: `gtgEnabled`, `gtgStartHour=9`, `gtgEndHour=21`, `gtgDailyTarget=50`, `gtgPromptCount=8`, `preferredGTGExercise`
- 환경 설정: `notificationSoundEnabled`, `hapticEnabled`

### UserDefaults (모델 외 영속)
| Key | 의미 |
|---|---|
| `repflow.autoDetect.enabled` | Bool, **기본 false**. 워치 모션 자동 감지 활성화 (실험적). `AutoDetectSettings` namespace 통해 접근 |
| `repflow.calibration.<exerciseRaw>` | `UserCalibration` JSON, per exercise. 자동 감지 켰을 때만 사용 |
| `repflow.sensitivity` | Double 0.7~1.3, 기본 1.0. 자동 감지 임계값 배수 |
| `repflow.totalCompletedSessions` | 누적 세션 (리뷰 트리거) |
| `repflow.review.lastTriggerCount` | 마지막 리뷰 임계 |
| `hasFinishedOnboarding` | 온보딩 완료 |

---

## 4. Rep Detection 알고리즘 (v3) — opt-in

> ⚠️ **2026-06-01부터 자동 감지는 기본 OFF.** `AutoDetectSettings.isEnabled()` 이 `true`일 때만 워치 화면이 detector를 시작한다. 기본 입력은 탭/크라운 카운트(§5 참조).
> 알고리즘 자체는 v3 유지. 폰 설정 → "자동 카운트" 페이지에서 토글하면 워치로 동기화됨(`CalibrationSyncKey.autoDetectEnabled`).

### 4.1 신호 파이프라인

`Shared/RepDetectorService.swift` — 50Hz `CMDeviceMotion`.

```
CMDeviceMotion ─┬─ userAcceleration (a) ┐
                ├─ gravity (g) ────────┤→ vertical = -(a·g)  (자세 무관 수직 가속도)
                └─ rotationRate (r) ───→ gyroMag = |r|        (회전 강도)
                                                              
EMA α=0.22 → sVertical, sGyro
                                                              
combined = sVertical + sign(sVertical) × sGyro × gyroWeight   (결합 신호)
```

**왜 gravity projection?** 워치 자세가 어떻든 사용자가 "위/아래"로 움직인 가속도만 추출. 푸시업 시 손목 시계가 어느 방향을 향하든 동일하게 잡힌다.

**왜 gyro fusion?** 푸시업에서 손목 자체의 vertical 가속도는 매우 작다 (관절 거의 고정). 그러나 팔꿈치 굴신 시 손목 **회전**은 일관되게 발생 → gyro magnitude를 동부호로 결합해 amplitude를 부풀린다.

### 4.2 Adaptive baseline

시작 직후 `noiseWindow = 1.5초` 동안 사용자 정지 상태의 `|combined|` 샘플 수집 → 95-percentile = noise floor → **threshold = max(noiseFloor × thresholdMultiplier, absoluteMinThreshold)**.

이 동안 화면에는 "정지 유지 (잡음 측정)" 오버레이 표시. baseline lock 시점에 `coord.haptic(.start)` 발생.

콜백:
- `onSignalUpdate(value, threshold, isCalibrated)` — UI bar 갱신
- baseline 완료 시 `isCalibrated = true` 로 전환

### 4.3 Zero-crossing detection

`combined` 의 부호가 `+threshold ↔ -threshold` 를 가로지를 때 half-cycle 완료. **2 half-cycles = 1 rep**. 각 half-cycle 중 `max |combined|` 가 threshold 이상이어야 valid.

- `minRepInterval` 이내 재카운트 차단 (false positive 방지)
- `maxRepInterval × 1.5` 초과 후 cycle 상태 리셋 (false continuation 방지)
- 캘리브레이션 모드에서는 valid rep마다 `collectedPeakAmplitudes`에 peak amp 누적

### 4.4 Per-exercise 튜닝 상수

`RepDetectorService.baseline(for:)` — exercise별 BaselineTuning:

| Exercise | minInterval | maxInterval | smoothing | gyroWeight | thresholdMult | absMinThreshold |
|---|---|---|---|---|---|---|
| `pushUp`, `pikePushUp` | 0.35 | 8.0 | 0.22 | **0.08** | 2.2 | 0.020 |
| `pullUp`, `inverseRow` | 0.50 | 8.0 | 0.25 | 0.04 | 2.5 | 0.040 |
| `dip` | 0.40 | 8.0 | 0.22 | 0.06 | 2.3 | 0.030 |

설계 의도:
- **푸시업**: 손목 변위 작음 → gyroWeight 높이고 threshold 낮춘다.
- **풀업**: 손목 변위 큼 → vertical 비중 높이고 threshold 올린다.
- **딥스**: 중간.

`applyTuning()`:
- `thresholdMultiplier *= sensitivity` (UserDefaults 0.7~1.3)
- `absoluteMinThreshold *= sensitivity`
- 캘리브레이션 모드에서는 추가로 `thresholdMultiplier *= 0.7`, `absoluteMinThreshold *= 0.6` (관대하게)

### 4.5 알고리즘 버전 관리

`RepDetectorAlgorithm.current = 3`. `UserCalibration` 저장 시 함께 기록.

`CalibrationStore.load(_:)` 에서 버전 불일치 → `nil` 반환 → 자동 재캘리브레이션 유도. v2 데이터는 자동 무효 처리됨.

**알고리즘 변경 체크리스트**:
1. `RepDetectorService` 로직 수정
2. `RepDetectorAlgorithm.current` 증가
3. SPEC §4 (이 절) 업데이트
4. 사용자에게 "재캘리브레이션 필요" 가이드 노출

### 4.6 캘리브레이션 데이터

`UserCalibration`:
```swift
struct UserCalibration: Codable {
    var exerciseRaw: String
    var avgUpAmplitude: Double      // 양수
    var avgDownAmplitude: Double    // 음수 (= -avgUpAmplitude in v3)
    var avgCycleSeconds: Double
    var sampleCount: Int
    var calibratedAt: Date
    var algorithmVersion: Int?      // 3
}
```
v3는 zero-crossing이라 up/down 구분 불필요 — 단일 amplitude로 처리.

`finalizeCalibration`: `repCount >= 3` 필요. 미달 시 nil 반환 + UI는 ready로 복귀.

---

## 5. Watch UI 상태 머신

`WatchCoordinator.Screen`:
```
.menu                                       — MenuView
.program(ProgramSession, restBonusSeconds)  — ProgramRunView    (「푸시업 100」, 폰 없이 완주 가능)
.workout(ExerciseKind, WorkoutMode)         — WorkoutLiveView   (freeCount 전용)
.interval(IntervalProgram)                  — IntervalRunView   (EMOM/Tabata/AMRAP)
.gtgQuick(ExerciseKind, Int)                — GTGQuickView      (GTG 알림 응답)
.calibrate(ExerciseKind)                    — CalibrationView   (5회 측정)
```

`backToMenu()` 으로 항상 menu 복귀.

### 5.1 UI 레이아웃 규약 (워치 화면 넘침 방지)

과거 사고: 시계 시스템 상단 시간 + 둥근 모서리에 버튼 잘림.

규약:
- 외곽 padding: `horizontal=8`, `top=4`, `bottom=2`
- 메인 카운터: `.font(.system(size: 60~64))` + `.minimumScaleFactor(0.5)` + `.lineLimit(1)`
- 메타 라인 (운동·시간·심박): `.font(.caption2)` + `.minimumScaleFactor(0.8)`
- 버튼: `.controlSize(.small)` + `.font(.footnote)`, `frame(maxWidth: .infinity)` 으로 양분
- 별도 헤더 텍스트 금지 — 시스템 시계와 충돌

### 5.2 입력 모델 (탭 카운트 주력)

워치 화면 카운트 입력은 두 가지가 항상 활성:
- **탭** — 카운터 영역(`Text("\(reps)")` 주변)을 탭하면 +1. `contentShape(Rectangle())` + `onTapGesture` 로 구현.
- **크라운 회전** — `digitalCrownRotation` 으로 ±1. `@FocusState`로 onAppear 시 자동 포커스. 한 클릭 = 1 rep.

`AutoDetectSettings.isEnabled()` 이 `true`이면 위 두 입력에 더해 모션 감지가 추가로 +1 콜백을 보낸다 (탭/크라운과 충돌 시 단순 누적).

### 5.3 화면별 동작

**`WorkoutLiveView`** (`.workout(exercise, .freeCount)`)
- `start()`: `WatchWorkoutManager.start(exercise:)`. `autoDetectEnabled` 면 `detector.start(...)` 추가.
- 카운터 영역 탭 = +1, 크라운 회전 = ±1.
- `−` 버튼(좌): undo (`reps > 0`일 때만 활성). `⏹` (우): `sendWorkoutEnded` 후 backToMenu.
- `reps == 0` 일 때 "화면 탭 = +1" 힌트 표시.
- 자동 감지 ON + baseline 미완료 시 "정지 유지 (잡음 측정)" 오버레이.

**`IntervalRunView`** (`.interval(program)`)
- `intervalTimer.start(program:)` + `HKWorkoutSession`. `autoDetectEnabled` 면 detector 추가.
- `work` 단계에서만 카운트 입력 활성: 탭 = +1 / `+`,`−` 버튼 / 크라운 = ±1.
- 단계 전환 시 햅틱: start/stop/success.
- 완료/정지 시 `sendWorkoutEnded`.

**`GTGQuickView`** (`.gtgQuick(exercise, reps)`)
- "시작" 누르면 카운트 시작. 카운터 영역 탭/크라운으로 ±1.
- 목표(`suggestedReps`) 도달 순간 `haptic(.success)`.
- "완료" → `sendGTGAck(reps: done)`, 시작 전 `xmark` → `sendGTGAck(reps: 0)`.
- 자동 감지 ON 일 때만 detector 동작.

**`CalibrationView`** (`.calibrate(exercise)`)
- 자동 감지 기능 전용. 워치 메뉴 → "고급" → 자동 감지 ON 일 때만 진입 노출.
- 4단계: `.ready` → `.baseline` → `.running` → `.done`.
- `mode: .calibrate` 로 시작. 5회 감지 시 `finalize()` → `UserCalibration` 저장.
- `signalBar`: 현재 `|signal|` / `(threshold × 2)` 를 0~1 정규화. threshold 선이 50% 지점.

### 5.4 MenuView 구성

- 상단: 운동 종목별 NavigationGroup (프리 카운트 / AMRAP 5분)
- 중간: 타바타·EMOM 빠른 시작
- 하단: **"고급"** 토글 섹션
  - 자동 감지 ON 시: 종목별 캘리브레이션 진입 버튼 노출
  - 자동 감지 OFF 시: "자동 감지는 폰 설정에서 켤 수 있어요 (실험적)" 안내

---

## 6. 메시지 프로토콜 (Watch ↔ iPhone)

`Shared/WatchMessage.swift`. 모든 키는 `WatchMessageKey` 상수.

### 6.1 Watch → iPhone (`WatchAction`)

| Action | 추가 페이로드 | 비고 |
|---|---|---|
| `repCounted` | `totalReps` | rep 카운트 갱신. 실시간 표시 전용, 유실 허용 |
| `workoutEnded` | `exercise`, `mode`, `totalReps`, `durationSec`, `avgTempo`, `timestamp`, `messageId` | 세션 완료. **보장 송신** |
| `gtgPromptAcknowledged` | `exercise`, `reps` (0 = 건너뜀), `timestamp`, `messageId` | GTG 프롬프트 응답. **보장 송신** |
| `programSessionCompleted` | `sessionResult` (JSON), `totalReps`, `timestamp`, `messageId` | 「푸시업 100」 세션 완료. **보장 송신**. 주간 판정은 폰이 한다 |
| `setCompleted` | - | (정의됨, 현재 미사용) |
| `requestProgram` | - | (정의됨, 미사용) |
| `workoutStarted` | - | (정의됨, 미사용) |

### 6.2 iPhone → Watch (`PhoneEvent`)

| Event | 추가 페이로드 | 비고 |
|---|---|---|
| `gtgPrompt` | `exercise`, `reps` | GTG 즉시 트리거 → 워치가 `GTGQuickView` 열기 |
| `programUpdated` | `programSession` (JSON), `restBonus` | 다음 「푸시업 100」 세션. `updateApplicationContext` 로 밀어 워치가 꺼져 있었어도 다음 활성화 때 받는다 |
| `startWorkout` | - | (정의됨, 미사용) |
| `stopWorkout` | - | (정의됨, 미사용) |

### 6.3 캘리브레이션 동기화 (`CalibrationSyncKey`)

iPhone Settings에서 sensitivity 또는 자동 감지 토글 변경 →
- `sendSensitivityUpdate(Double)` — `sensitivity` 키
- `sendAutoDetectEnabled(Bool)` — `autoDetectEnabled` 키

둘 다 `event: "calibrationSync"` 로 통일. `updateApplicationContext` (백그라운드 적용) + `sendMessage` (즉시) 듀얼 전송.

워치측 `WatchSessionService.handleIncoming` 에서 두 키 모두 처리:
- `sensitivity` → `CalibrationStore.setSensitivity`
- `autoDetectEnabled` → `AutoDetectSettings.setEnabled`

### 6.4 전송 신뢰도 티어 (2026-09-20 개정)

메시지를 두 등급으로 나눈다. 전에는 전부 한 경로였고, 폰 쪽에 `didReceiveUserInfo` 구현이
없어서 폴백으로 넘어간 메시지가 **전부 조용히 버려지고 있었다** (§12 교훈 #12).

| 등급 | 대상 | 송신 | 이유 |
|---|---|---|---|
| 실시간 | `repCounted` | `sendMessage` 만. 닿지 않으면 버린다 | 다음 rep이 곧 덮어쓴다. 큐잉하면 철 지난 값이 뒤늦게 도착 |
| 보장 | `workoutEnded`, `gtgPromptAcknowledged` | `sendReliably` — 닿으면 `sendMessage`(빠름) **+ 항상** `transferUserInfo`(지속 큐) | 기록으로 남아야 하는 유일한 경로. 유실 = 운동 한 번이 사라짐 |

보장 등급은 두 경로가 모두 도착할 수 있으므로 송신 시 `messageId`(UUID)를 붙이고,
폰의 `ProcessedMessageLog` 가 UserDefaults에 최근 50개를 남겨 중복을 제거한다.
앱 재시작 후 큐에 남은 사본이 재배달되는 경우까지 커버하기 위해 메모리가 아닌 UserDefaults다.

### 6.5 수신 단일 디스패처

폰의 수신 경로는 셋(`didReceiveMessage` / `didReceiveUserInfo` / `didReceiveApplicationContext`)인데
셋 다 `PhoneSessionService.handle(_:)` 하나로 모인다. 경로별로 처리를 나누면 한쪽만 고치는 사고가 난다.

파싱은 `Shared/WatchPayload.swift` 의 `WatchPayload.parse(_:)` — `WCSession` 의존이 없는 순수
Foundation 코드라 단독 테스트 가능하다.

⚠️ 시각은 **워치가 찍은 `timestamp`** 를 쓴다(`workoutEnded`, `gtgPromptAcknowledged` 모두).
큐잉된 메시지는 몇 시간 뒤에 도착할 수 있어 수신 시각(`.now`)을 쓰면 기록 시각이 틀어지고,
GTG는 자정을 넘기면 아예 다른 날짜에 적립된다.

---

## 7. iPhone-Watch 라이프사이클

### 7.1 진입점

- **iPhone**: `RepFlowApp.init` 에서 `PhoneSessionService.shared.activate()` 호출. SwiftData container 마운트.
  - 영속화는 주입이 아니라 **지연 조회**다 (`PhoneSessionService.activeIngest`). 워치가 폰을 백그라운드로
    깨우면 Scene 의 `.task` 가 돌지 않아 주입 시점이 없는데, 바로 그때 도착하는 메시지가 저장돼야 할 기록이다.
    테스트는 `ingestOverride` 로 인메모리 컨텍스트를 끼운다.
- **Watch**: `RepFlowWatchApp.init` 에서 `WatchSessionService.shared.activate()`. `.task` 에서 `WatchWorkoutManager.requestAuthorization()` (HealthKit 권한).

### 7.2 백그라운드 실행

- **Watch**: 운동 시작 시 `HKWorkoutSession` 시작 → 워치가 CPU 시간을 받아 화면 꺼져도 모션 디텍션 + 햅틱 지속.
- **iOS**: `UIBackgroundModes = [fetch, processing]`, `BGTaskSchedulerPermittedIdentifiers = ["com.digimaru.repflow.gtg.refresh"]`. 현재 BG task 핸들러 미구현 — GTG 알림은 `UNCalendarNotificationTrigger` 로 OS에 위임.

### 7.3 HKWorkoutActivityType 매핑

```
pushUp, pikePushUp, dip   → .functionalStrengthTraining
pullUp, inverseRow        → .traditionalStrengthTraining
```

### 7.4 HealthKit 권한

- 공유(write): workoutType, activeEnergyBurned
- 읽기(read): workoutType, activeEnergyBurned, heartRate
- entitlement: `com.apple.developer.healthkit: true` (xcodegen `properties:` 로 자동 생성)
- ⚠️ `com.apple.developer.healthkit.access` 는 사용 금지 — verifiable health records 용, Apple 별도 승인 필요.

---

## 8. GTG 스케줄링

`GTGSchedulerService.scheduleToday(profile:)`:
1. `gtgEnabled` 가드, `endHour > startHour` 가드.
2. `requestAuthorization([.alert, .sound, .badge])`.
3. `cancelAll()` — 기존 펜딩 모두 제거.
4. `count = gtgPromptCount`, `perPrompt = max(1, gtgDailyTarget / count)`.
5. `totalMinutes = (endHour - startHour) × 60`, `interval = totalMinutes / count`.
6. 0..<count 반복:
   - `minuteOffset = i * interval + interval/2 + randomJitter(-8…+8)`
   - `dayStart + minuteOffset` 시각에 `UNCalendarNotificationTrigger` 예약
   - title: `"💪 GTG: <displayName> <perPrompt>개"`
   - body: `"지금 가볍게! 절대 한계까지 가지 말 것 (RPE 5)."`
   - `categoryIdentifier = "REPFLOW_GTG"`, actions: `REPFLOW_GTG_ACK` / `REPFLOW_GTG_SKIP`

⚠️ 현재 알림 액션 핸들러는 미구현. 사용자가 알림 탭 → 앱 열림 → 워치 사용 흐름은 직접 검증 필요.

---

## 9. 빌드 / 배포

### 9.1 로컬 빌드

```bash
# project.yml 변경 시 .xcodeproj 재생성
xcodegen generate

# iOS 시뮬레이터 빌드
xcodebuild -scheme RepFlow -project RepFlow.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 9.2 TestFlight

```bash
fastlane beta
```

`fastlane/Fastfile` 동작:
1. ASC API key 로드 (외부 경로 `/Volumes/SSD/DEV_SSD/MY/BurnCoach/fastlane/AuthKey_33P5W93GJQ.p8` — RepFlow와 BurnCoach가 같은 키 공유)
2. `latest_testflight_build_number` + 1 → `increment_build_number`
3. `xcodebuild ... archive` with `-allowProvisioningUpdates` + API key (자동 서명)
4. `xcodebuild -exportArchive ... -exportOptionsPlist fastlane/ios_export.plist`
5. `upload_to_testflight` with changelog from last 10 commits
6. `clean_build_artifacts`

⚠️ **MARKETING_VERSION은 TestFlight 단조 증가 필수** — 같은 버전+빌드 조합은 거부됨. 빌드 번호는 fastlane이 자동 처리, 마케팅 버전은 `project.yml` 에 명시 (현재 1.0.3).

### 9.3 lanes

- `beta` — TestFlight 업로드
- `test` — 유닛 테스트 (iPhone 17)
- `upload_metadata` — 스크린샷 + 메타데이터 ASC 업로드 (binary skip)

### 9.4 Untracked 파일 (.gitignore 후보)

- `AppStore_com.digimaru.repflow.mobileprovision` — provisioning profile, **commit 금지**
- `AppStore_com.digimaru.repflow.watch.mobileprovision` — 동상
- `fastlane/ios_export.plist` — 배포 옵션. 현재 lane이 참조 → commit 필요 가능성 있음. 확인할 것.

---

### 9.4.5 실기기 설치 (TestFlight 불필요)

개발 중 검증은 TestFlight를 거치지 않는다. 빌드 → 업로드 → 처리 대기가 매번 10~20분인데
필요한 건 즉각 피드백이다. TestFlight는 출시 직전 실제 결제 흐름과 배포용 빌드 확인용이다.

```sh
export DEVELOPER_DIR=/Volumes/SSD/Applications/Xcode.app/Contents/Developer
PHONE=00008110-000A08940E01801E    # iPhone 13 "Mare"
WATCH=00008310-000C3C9426A0E01E    # Apple Watch SE 3

xcrun devicectl list devices                       # UDID 확인
xcodebuild build -project RepFlow.xcodeproj -scheme RepFlow \
  -destination "platform=iOS,id=$PHONE" -allowProvisioningUpdates \
  -authenticationKeyID 33P5W93GJQ \
  -authenticationKeyIssuerID ed28e2d3-ce1d-4d24-8e58-373132e4b554 \
  -authenticationKeyPath /Volumes/SSD/DEV_SSD/MY/BurnCoach/fastlane/AuthKey_33P5W93GJQ.p8
xcrun devicectl device install app --device $PHONE \
  ~/Library/Developer/Xcode/DerivedData/RepFlow-*/Build/Products/Debug-iphoneos/RepFlow.app
xcrun devicectl device process launch --device $PHONE com.digimaru.repflow
```

⚠️ **워치는 기기에서 개발자 모드를 먼저 켜야 한다** (설정 → 개인정보 보호 및 보안 → 개발자 모드).
꺼져 있으면 기기 등록이 안 되어 프로비저닝 프로파일에 워치 UDID가 들어가지 않고,
동봉된 워치 앱이 조용히 설치되지 않는다 (§12 교훈 #17).

설치된 프로파일에 기기가 들어갔는지 확인:
```sh
security cms -D -i <App>.app/Watch/<Watch>.app/embedded.mobileprovision \
  | plutil -extract ProvisionedDevices xml1 -o - -
```

### 9.5 스크린샷 자동화 훅

실기기 없이 특정 화면을 캡처하기 위한 런치 인자(`MockDataLoader`).

| 인자 | 효과 |
|---|---|
| `UI_TESTING` | UI 테스트 모드 |
| `UI_TESTING_MOCK_DATA` | 프로필·세션·GTG·**프로그램 진행 상태** 주입 |
| `UI_TESTING_SKIP_ONBOARDING` | 온보딩 건너뛰기 |
| `UI_TESTING_PRO` | Pro 활성 |
| `UI_TESTING_TAB=n` | 시작 탭 (0 홈 / 1 푸시업100 / 2 기록 / 3 설정) |
| `UI_TESTING_ROUTE=session` | 프로그램 세션 화면을 바로 연다 |

```sh
xcrun simctl launch "iPhone 17" com.digimaru.repflow \
  UI_TESTING UI_TESTING_MOCK_DATA UI_TESTING_SKIP_ONBOARDING UI_TESTING_TAB=1
xcrun simctl io "iPhone 17" screenshot shot.png
```

---

## 10. Pro 구독 / 수익화

`ProManager.swift` — StoreKit 2.

Product IDs:
- `com.digimaru.repflow.pro.monthly`
- `com.digimaru.repflow.pro.yearly`
- `com.digimaru.repflow.pro.lifetime`

Gating:
- `GTGSettingsView` — `gtgEnabled` 토글 시 `!isPro` 이면 `PaywallView` 시트.

리뷰 프롬프트:
- `ReviewPromptService.sessionCompleted(totalCount:)` — 누적 5/15/40/100 도달 시 `SKStoreReviewController` 1.2초 지연 트리거. Apple 365일/3회 제한 안에서 4개만 사용.

---

## 11. 디자인 시스템

`Presentation/Components/Theme.swift` 의 `RFColor` / `RFSpace` / `RFRadius`. Linear-inspired dark scheme.

- 배경: `#0B0B0E` (UITabBar / UINavigationBar 도 동일)
- AccentColor: AssetCatalog `Color("AccentColor")` (앱 전반 `.tint`)
- 4언어 로컬라이제이션: en (기본), ko, ja, zh-Hans

운동 픽토그램: `Assets.xcassets` 의 `exercise_pushup/pullup/dip/row/pike` — `.template` renderingMode. `ExerciseKind.pictogram: Image` 로 SwiftUI 통합.

---

## 12. 과거 사고 / 교훈 (Lessons Learned)

| # | 사고 | 교훈 / 해법 |
|---|---|---|
| 1 | `com.repflow.app` 번들 ID 이미 ASC 등록됨 | 본인 prefix 사용 (`com.digimaru.*`) |
| 2 | xcodegen `entitlements.properties:` 가 파일을 덮어씀 | properties 사용 시 파일 내용 자동 생성. 빈 `<dict/>` 유지하려면 `path:` 만 지정 |
| 3 | `com.apple.developer.healthkit.access` entitlement 사용 → Apple 별도 승인 필요 (verifiable health records) | 일반 HealthKit 만 쓰면 `com.apple.developer.healthkit: true` 하나만. `.access` 키는 절대 추가 금지 |
| 4 | Shared/ 파일에서 `import UIKit` / `import WatchKit` | watchOS 타깃이 빌드 실패. **Foundation, SwiftUI, CoreMotion만 사용** |
| 5 | TestFlight 같은 MARKETING_VERSION + 빌드번호 거부 | 마케팅 버전은 단조 증가, fastlane이 빌드 번호 자동 +1 |
| 6 | 워치 둥근 화면 모서리에서 버튼 잘림 + 시스템 시계와 헤더 겹침 | §5.1 레이아웃 규약 준수 |
| 7 | v2 알고리즘: 단순 vertical-only threshold로 푸시업 미감지 | v3로 자이로 fusion + adaptive baseline 도입 (§4) |
| 8 | fastlane `produce` 가 non-interactive 셸에서 spaceship password 요구 | Fastfile에서 produce 제거. ASC API key 만으로 자동 서명 (`-allowProvisioningUpdates`) |
| 9 | `errSecInternalComponent` CodeSign 실패 — 키체인에 cert 없음 / partition list 미설정 | (1) Apple Distribution cert 수동 import 후 (2) `security set-key-partition-list -S apple-tool:,apple:,codesign: ...` 또는 (3) `-allowProvisioningUpdates` 사용 |
| 10 | SourceKit IDE에서 `Cannot find type 'ExerciseKind'` / `No such module 'WatchKit'` | macOS evaluation context의 false positive — 실제 `xcodebuild` 빌드 성공. 무시 |
| 11 | v3 자동 감지 알고리즘을 계속 튜닝해도 푸시업 카운트 실패 — 손목 가속도 진폭이 노이즈와 본질적으로 겹침 (Apple Fitness도 미해결) | 워치는 **탭/크라운 카운트 주력**으로 전환. 자동 감지는 `AutoDetectSettings` opt-in 토글로 강등. 정확한 자동 카운트는 폰 카메라(Vision) Pro 기능으로 Phase 2 진행 |
| 12 | 워치 운동 기록이 **한 번도 저장된 적이 없었다** — `WorkoutSession` 을 insert 하는 코드가 UI 테스트용 `MockDataLoader` 뿐이라 실사용에서 `HistoryView` 가 영원히 비었다 | 수신 → 영속 경로를 `WorkoutIngestService` 로 분리하고 인메모리 컨테이너로 테스트. 모델을 정의하고 화면을 붙였다고 저장이 되는 게 아니다 — **`@Query` 가 비어 있는지 실기기에서 확인**할 것 |
| 13 | 워치가 `transferUserInfo` 로 폴백해도 폰에 `didReceiveUserInfo` 구현이 없어 전부 버려짐. 에러도 로그도 없음 | `WCSessionDelegate` 는 구현하지 않은 콜백을 조용히 무시한다. **송신 경로를 추가하면 수신 경로도 같은 커밋에서** 추가하고, 세 경로를 단일 디스패처로 모을 것 (§6.5) |
| 14 | Xcode 27 에서 `RepFlowUITests` 컴파일 실패 — fastlane `setupSnapshot`/`snapshot` 이 MainActor 격리 전역 함수 | 스냅샷 테스트 클래스에 `@MainActor`. `-only-testing:` 을 줘도 스킴의 **모든** 테스트 타깃이 빌드되므로 UI 테스트가 깨지면 유닛 테스트도 못 돈다 |
| 15 | `project.yml` 의 `xcodeVersion` 이 16.0 인데 이 맥에는 Xcode 27.0 만 설치됨 | xcodegen 값은 실제 설치 버전을 따라간다. `xcodebuild -version` 으로 먼저 확인 |
| 16 | 카메라 모드를 눌러도 거치 가이드가 안 열림 | 같은 `NavigationStack` 안에 `navigationDestination(isPresented:)` 가 **둘 이상**이면 서로 충돌해 열리지 않는다. 카메라 가이드는 `fullScreenCover` 로 전환. 부모의 `onDisappear` 가 가이드가 막 켠 캡처를 끄는 문제도 같이 해결됨 |
| 17 | 워치에 개발자 빌드가 설치되지 않음 | **워치 자체의 개발자 모드**가 꺼져 있었다(설정 → 개인정보 보호 및 보안 → 개발자 모드). 꺼져 있으면 워치가 기기 등록조차 안 되어 프로비저닝 프로파일에 UDID가 안 들어간다. `security cms -D -i embedded.mobileprovision` 으로 `ProvisionedDevices` 를 직접 확인할 것 |
| 18 | 워치 프로파일 Platform 이 `iOS/xrOS/visionOS` 로 잡힘 | 워치가 등록되지 않아 watchOS 프로파일이 생성되지 못하고 iOS 프로파일이 재사용된 결과. #17을 고치면 함께 해결된다 |
| 19 | `project.yml` 워치 의존성에 `codeSign`/`platformFilter`, 타깃에 `SKIP_INSTALL` 누락 | BurnCoach·RunStamp 의 검증된 형태를 따른다: 의존성 `embed: true, codeSign: true, platformFilter: iOS` / 타깃 `SKIP_INSTALL: YES`. 없으면 기기 설치·아카이브 검증에서 문제가 난다 |

---

## 13. SPEC 유지 프로토콜 ⚠️

### 13.1 새 세션을 시작할 때

1. 이 파일을 **먼저** 읽는다 (코드보다 우선).
2. §0 Status로 현재 버전 / 알고리즘 / 미해결 항목 파악.
3. 사용자의 요청과 §0의 미해결 항목이 일치하는지 확인.
4. 코드를 확인하기 전에 SPEC의 관련 절을 먼저 읽어 컨텍스트 파악.

### 13.2 작업 진행 중

코드 변경이 다음 중 하나에 영향을 주면 **즉시** SPEC도 업데이트:
- 알고리즘 (§4) — 버전 번호 증가 필수
- 데이터 모델 / UserDefaults 키 (§3)
- Watch UI 상태 또는 레이아웃 규약 (§5)
- 메시지 키 / 액션 / 이벤트 (§6)
- 빌드 구성 / 배포 절차 (§9)
- 새로 발견한 함정 → §12에 한 줄 추가

### 13.3 작업 종료 시

- §0 Status 표 (버전 / 빌드 / 마지막 커밋) 갱신
- §0 "미해결 / 대기 항목" 에서 완료된 항목 제거, 새 항목 추가
- TestFlight 배포 후엔 빌드 번호 + 알고리즘 버전 명시
- 가능하면 같은 커밋에 SPEC 변경 포함 (그래야 git history와 SPEC이 동기)

### 13.4 무엇을 SPEC에 적지 않는가

- 일회성 디버깅 로그 / 실험 결과
- 단순히 "코드를 읽으면 알 수 있는" 함수 시그니처 나열
- 사용자별 메시지 내용 (모두 한국어 / errorDescription 통해 — 코드가 진실)
- 직전 커밋의 변경 내용 (그건 `git log` 가 진실) — 단, **의도/근거** 가 있으면 §12에 적는다

### 13.5 SPEC ≠ README

- `README.md` — 외부 사용자/기여자 대상 소개
- `DESIGN.md` — 디자인 시안 / 와이어프레임
- `ASO.md` — 앱스토어 최적화 메타데이터
- `CLAUDE.md` — Claude 에이전트 진입 지점 (→ SPEC.md 참조 지시)
- **`SPEC.md` (이 문서)** — 현재 상태의 단일 진실. Claude 작업의 출발점.


---

## 14. 푸시업 100 프로그램

`Shared/PushUpProgram.swift`. 순수 Foundation — iOS·watchOS 양쪽에서 컴파일되고 단독 테스트된다.

> ⚠️ 시판 6주 프로그램의 표를 베끼지 않았다(저작권 + 기억 재현 부정확). 자체 설계한 비율 기반
> 사다리이고, 아래 상수는 **초기값**이다. 실사용 데이터가 쌓이면 조정한다.

### 14.1 레벨 (`PushUpLevel`)

최대 측정(폼 유지 AMRAP 한 세트) 결과 `M` 으로 배정. 레벨은 **휴식 시간과 무릎 변형 허용 여부만**
결정한다. 세트 수치는 레벨이 아니라 훈련최대 `W` 의 비율로 나온다.

| 레벨 | M | 휴식 | 비고 |
|---|---|---|---|
| L1 | ≤5 | 90s | 무릎 푸시업 허용 |
| L2 | 6–10 | 90s | |
| L3 | 11–20 | 90s | |
| L4 | 21–30 | 60s | |
| L5 | 31–45 | 60s | |
| L6 | 46+ | 60s | 100 사정권 |

⚠️ `allowsKneeVariant` 는 폼 분석기(M5)도 읽어야 한다. 무릎 푸시업에서 힙라인을
`shoulder–hip–ankle` 로 재면 모든 rep이 "허리 처짐"으로 오판된다 → `shoulder–hip–knee` 로 바꿀 것.

### 14.2 주 3회 세션 (`SessionKind`)

| 세션 | 고정 4세트 비율 | AMRAP 하한 | 휴식 |
|---|---|---|---|
| A 볼륨 | `.40 .50 .40 .40` | `.40` | 레벨 기본 |
| B 강도 | `.50 .60 .50 .50` | `.50` | 레벨 기본 |
| C 밀도 | `.45 ×4` | `.45` | 레벨 기본의 **절반** |

각 세트 목표 = `max(1, round(비율 × W))`. 한 주 합계 ≈ 6.95W, 상한은 8W(안전장치).

### 14.3 주기

- **디로드**: 4주마다 전 세트 볼륨 60%
- **재측정**: 7주마다. 사다리 대신 AMRAP 한 세트만 하고 `W = 새 M`
- 둘이 겹치는 주(28, 56…)는 **재측정이 우선**

### 14.4 진행 판정 (`ProgressionRule.apply`)

**주 1회, 그 주 세 세션이 끝난 뒤에만 부른다.** 세션마다 +10%를 적용하면 주당 +33%가 되어
며칠 만에 "2주 연속 미달"로 무너진다. 한 주가 한 단위다.

- 세 세션 모두 고정 세트 달성 **AND** AMRAP 여유 평균 ≥ +3 → `W += max(1, round(W × 0.1))`, 미달 카운터 0
- 아니면 미달 카운터 +1. **2주 연속** 미달이면 `W -= 10%`, 휴식 +30s, 카운터 0
- **디로드·재측정 주간은 판정하지 않는다**(미달로도 세지 않는다). 특히 재측정은 세트가 하나뿐이라
  `metFixedSets` 가 항상 false가 되어, 막지 않으면 재측정을 할 때마다 미달이 적립된다.
  재측정 결과로 `W = 새 M` 을 잡는 건 호출자의 몫이다
- `W` 는 1 아래로 내려가지 않고, 증감은 최소 1

### 14.5 졸업과 예측

- **졸업 = 한 세트 100개** (`ProgramLadder.hasGraduated`)
- `estimatedWeeksTo100(history:)` — 최근 4주 `W` 증가분으로 선형 외삽. 정체·감소·이력 부족이면
  **nil**. 모르면 모른다고 해야지 아무 숫자나 보여주면 안 된다.

매주 성공하는 이상적 경우 기준(참고값, 상한 아님):

| 시작 최대 | 100까지 |
|---|---|
| 5개 | 46주 (~11개월) |
| 12개 | 34주 (~8개월) |
| 25개 | 23주 (~5개월) |
| 40개 | 15주 (~3.5개월) |

### 14.6 세션 진행 상태머신 (`ProgramSessionRunner`)

`Shared/ProgramSessionRunner.swift`. `@Observable`, Foundation + Observation 만 import.

```
ready → working(setIndex) ⇄ resting(afterSetIndex, until) → … → finished
                                                          ↘ abandoned
```

**폰과 워치가 같은 것을 쓴다.** 카운트가 어디서 오는지(탭·크라운·카메라·근접센서·모션)는
이 타입이 알 필요가 없다 — 모든 소스가 `addRep(_:)` 하나로 들어온다. UI 안에 상태를 넣으면
M4에서 워치용으로 통째로 다시 만들어야 한다.

- 시계를 주입받는다(`now: () -> Date`) → 테스트가 실제로 기다리지 않는다
- 마지막 AMRAP 세트에는 상한도 그 뒤 휴식도 없다
- `abandon()` 은 남은 세트를 0회로 채워 `SessionResult` 길이를 맞춘다. 안 그러면
  `metFixedSets` 가 조용히 false를 낸다
- `result` 는 끝난 뒤에만 나오고, 그대로 `ProgressionRule.apply` 에 넣을 수 있다

### 14.7 진행 상태 영속화 (`ProgramEnrollment`)

`@Model`. 규칙은 전부 `Shared/` 의 순수 함수에 있고, 이 모델은 그 함수들이 요구하는 상태만 들고 있다.

| 필드 | 쓰임 |
|---|---|
| `trainingMax` | 현재 `W` |
| `trainingMaxHistory` | 주차별 이력 → 100까지 남은 기간 예측 |
| `currentWeek` | 1부터 |
| `completedSessionsThisWeek` | 주가 끝나면 판정 후 비운다 |
| `consecutiveMissedWeeks`, `restBonusSeconds` | `ProgressionRule` 이월 상태 |
| `bestSingleSet`, `graduatedAt` | 졸업 판정 |

`record(_:)` 가 세션을 적립하고, 그 주 세션 수를 채우면 `finishWeek` 가 판정 후 다음 주로 넘긴다.
재측정 주는 판정이 아니라 실측이라 결과가 곧 새 `W` 가 된다.

⚠️ **아직 없는 것: 휴식일 강제.** 한 주를 다 끝내면 `nextSession` 이 곧바로 다음 주 A 세션을 연다.
하루에 몰아서 할 수 있다는 뜻이다. 날짜 기반 스케줄링은 UI(M3) 또는 후속에서 다룬다.
테스트 헬퍼에서 `while !isWeekComplete` 로 돌면 무한 루프가 되는 것도 같은 이유다.

### 14.8 자동 카운트 (M5·M6)

판정은 전부 **순수 타입**에 있고 프레임워크 클래스는 배관만 한다. 그래서 시뮬레이터에서
합성 신호로 검증할 수 있다 — 실기기에서만 확인 가능한 것은 Vision의 관절 추정 정확도뿐이다.

```
카메라  AVCapture → Vision 관절 ─┐
근접센서 proximityState ─────────┼→ PoseGeometry.depth → DepthRepDetector → addRep()
탭/크라운 ──────────────────────┘ (기하 없이 바로)
```

**`DepthRepDetector`** — 0(락아웃)~1(바닥) 신호를 히스테리시스(0.25 / 0.75)와 **구간 연속
체류 시간**(0.35s)으로 판정한다. 진입 시각만 보면 0.05초 간격으로 위아래를 오가는 신호도
통과해 버린다. 두 종류의 소스를 모두 받는다:
- 연속 샘플링(카메라 30fps) — 같은 구간이 이어지는 동안 체류가 쌓인다
- 희소 이벤트(근접센서는 바뀔 때만 알려준다) — 구간을 **떠날 때** 직전 체류로 판정.
  ⚠️ 마지막 1회는 다음 이벤트가 없어 미완성으로 남으므로 **세션 종료 시 `flush(at:)` 필수**

**`PoseGeometry`** — 정측면 촬영이라 **카메라를 향한 쪽** 팔다리만 쓴다(반대쪽은 몸에 가려
Vision이 저신뢰 좌표를 낸다). 깊이 산출은 두 방식이 있고 **실기기 기준 영상으로 확정한다**:
| 방식 | 장점 | 약점 |
|---|---|---|
| `elbowAngle` (기본) | 직관적 | 팔꿈치를 벌리면 투영에서 각이 압축됨 |
| `shoulderDrop` | 카메라 거리·체격에 불변 | 락아웃 기준값을 먼저 잡아야 함 |

⚠️ 폼 점수의 힙라인은 **변형에 따라 기준점이 다르다**: 정자세 `shoulder–hip–ankle`,
무릎 푸시업(L1) `shoulder–hip–knee`. 안 그러면 L1 사용자의 모든 rep이 "허리 처짐"으로 오판된다.
`PushUpLevel.allowsKneeVariant` 가 이 분기를 결정한다.

**`PlacementCheck` / `PlacementGuideView`** — 카메라 모드의 실질적 MVP는 카운터가 아니라
**시작을 막는 게이트**다. 푸시업은 바닥 자세라 셀피 각도로는 절대 잡히지 않는데, 안내 없이
열어두면 대부분 천장을 찍다가 0개로 끝난다. 판정 순서(각도 → 거리)가 중요하다 — 서 있는
사람은 가로 폭이 좁아서 순서를 바꾸면 "더 가까이 오세요"라는 엉뚱한 안내가 나간다.
3초 연속 통과해야 시작 버튼이 열리고, 거치 확인은 **세션당 한 번**이다(세트마다 시키면 못 쓴다).

**음성** — 장식이 아니다. 푸시업 자세에서는 화면을 볼 수 없고 근접센서 모드는 화면이 꺼진다.
`.duckOthers` + `.mixWithOthers` 로 음악을 끊지 않고 얹는다.

### 14.9 실기기 튜닝 과제 (M5 미완)

시뮬레이터에는 카메라도 근접센서도 없다. **아래는 전부 실기기에서만 확정된다.**

> 🔴 **0. 가장 먼저 의심할 것 — Vision orientation.**
> `CameraRepCounter.captureOutput` 은 지금 `VNImageRequestHandler(cvPixelBuffer:orientation: .up)` 이다.
> `.up` 은 버퍼를 센서 기준 가로로 본다는 뜻인데, 이 앱은 **세로 고정**(`UIInterfaceOrientationPortrait`)
> 이라 후면 카메라에서는 `.right` 가 맞을 가능성이 높다.
> 틀리면 축이 90° 돌아가 **멀쩡히 누운 사람이 세로로 길게 들어오고**, `PlacementCheck` 의
> 정측면 판정(`span > height`)이 영원히 실패해 "폰을 바닥에 세워 옆에서 찍어주세요"만 반복된다.
> 카메라 모드가 "아예 안 된다"면 십중팔구 여기다. 실기기에서 관절 좌표를 한 번 찍어보고 확정할 것
> — 추측으로 바꾸지 않았다.
>
> 관련 위험: `ProgramSessionView.onDisappear { stopSource() }` 가 `PlacementGuideView` 를 **push** 할 때도
> 불릴 수 있다. 그러면 가이드가 막 켠 카메라가 곧바로 꺼진다. 되돌아올 때 `onAppear` 가 우연히
> 살려내지만 순서에 의존한다. **가이드 화면이 새까맣게 나오면 이것부터 본다.**

1. 20회 기준 영상 3종(정측면 / 30° 사선 / 저조도)을 **리포 밖**에 녹화 보관
2. `DepthMethod` 두 방식을 같은 영상으로 비교 → 하나 확정
3. `DepthRepDetector` 임계(0.25 / 0.75 / 0.35s)를 기준 영상 오차 ≤±1회가 되도록 조정
4. `PlacementCheck` 거리 상수(`minBodySpan` 0.30 / `maxBodySpan` 0.88)를 실제 1.5~2m 촬영으로 검증
5. `FormScore` 임계(깊이 95° / 락아웃 160° / 힙 20°)를 육안 라벨과 대조
6. 근접센서 모드는 책상에서 20/20 확인 (실기기 필요하지만 운동은 불필요)
