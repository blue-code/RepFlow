# RepFlow

> 워치가 하루 종일 너의 푸시업/풀업 코치가 된다.

iOS + watchOS 운동 앱. 푸시업/풀업 자동 카운트 + GTG (Grease the Groove) 모드 + 인터벌 트레이너.

## 차별점

1. **GTG 모드** — 검증된 푸시업/풀업 진보 훈련법. 워치가 하루 종일 가벼운 푸시업/풀업 알림을 분산해서 보냄. 절대 한계까지 가지 않고 신경계 적응을 유도.
2. **인텔리전트 인터벌** — EMOM, Tabata, AMRAP. 워치 햅틱으로 라운드 전환.
3. **자동 rep 카운트** — CoreMotion (가속도/자이로) 기반 워치 모션 디텍션.
4. **로컬 퍼스트** — 모든 데이터 온디바이스. 광고 없음.

## 아키텍처

```
RepFlow/             — iOS 앱 (홈/프로그램/기록/설정)
RepFlowWatch/        — watchOS 앱 (운동/인터벌/GTG 퀵)
Shared/              — 공통 (운동 모델, 인터벌 타이머, RepDetector, Watch 메시지)
fastlane/            — TestFlight 배포
```

## 기술 스택
- iOS 17+ / watchOS 10+
- SwiftUI + `@Observable`
- SwiftData (영속화)
- CoreMotion (rep 디텍션)
- WatchConnectivity (디바이스 통신)
- UserNotifications (GTG 알림)

## 빌드 & 배포

```bash
# 프로젝트 생성
xcodegen generate

# 시뮬레이터 빌드
xcodebuild -scheme RepFlow -project RepFlow.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# TestFlight 업로드
AUTO_INCREMENT_BUILD_NUMBER=true fastlane beta
```

## 라이선스
MIT
