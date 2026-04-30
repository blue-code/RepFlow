# RepFlow ASO Strategy

> App Store Optimization: 검색 유입 최대화 + 전환율 향상.

## Apple 인덱싱 룰 (필수 이해)

Apple은 다음 필드를 검색에 사용한다:
1. **App Name** (30자) — 가중치 가장 높음
2. **Subtitle** (30자) — 두 번째 가중치
3. **Keywords field** (100자, 콤마 구분) — 보조 인덱싱
4. **Description** — 인덱싱 약함 (약간만 영향)
5. **In-App Purchase 이름/설명** — 인덱싱됨
6. **Promotional text** (170자) — 인덱싱 안 됨, 전환만

**핵심 원칙: Name·Subtitle에 들어간 단어를 Keywords에 다시 넣으면 100자를 낭비한다.**

한국어는 토큰화 차이로 콤마 없이 단어를 나열해도 인덱싱됨 (단, 콤마 구분이 안전).

## 키워드 우선순위 (검색량 vs 경쟁)

### High volume / High competition (피해야 할 함정)
- `pushup`, `pullup`, `workout` — 영문 카테고리 1티어. 신규 앱은 묻힘.

### Medium volume / Lower competition (우리 타겟)
- `calisthenics tracker`, `bodyweight counter`, `apple watch pushup`
- `GTG`, `grease the groove` — 매우 좁지만 정확히 매칭되면 강력
- `tabata pushup`, `EMOM bodyweight`

### Long-tail (전환율 높음)
- `apple watch rep counter`, `pushup auto count`, `calisthenics interval`

전략: **Long-tail + niche-specific 단어로 ranking 1-3위 확보 → 점진적 main keyword 노린다**.

## 4언어 Name/Subtitle/Keywords 분리 전략

각 언어에서 **Name + Subtitle + Keywords 필드 간 단어 중복 0**을 목표로 한다.

### 한국어 (ko)

| 필드 | 내용 | 글자수 |
|------|------|--------|
| Name | `RepFlow: 푸시업 풀업 카운터` | 16자 |
| Subtitle | `Apple Watch GTG 홈트 트레이너` | 23자 |
| Keywords | 칼리스테닉스,EMOM,타바타,체중운동,상체,복근,근력,운동기록,자세교정,홈트레이닝,데일리,훈련 | ~85자 |

논리:
- Name: 검색 단골인 "푸시업/풀업 카운터"를 직접 노출
- Subtitle: GTG + Apple Watch + 홈트 (검색 다른 축)
- Keywords: 카테고리 부수 키워드 (칼리스테닉스, EMOM, 타바타 등)

### English (en-US)

| 필드 | 내용 | 글자수 |
|------|------|--------|
| Name | `RepFlow: Pushup Pullup Counter` | 30자 (max) |
| Subtitle | `Watch GTG Calisthenics Coach` | 28자 |
| Keywords | tabata,emom,amrap,bodyweight,reps,fitness,strength,interval,trainer,gym,home,abs | 86자 |

논리:
- Name: pushup/pullup (compound) + counter (search 강력)
- Subtitle: GTG (정확 매칭) + calisthenics (니치)
- Keywords: 모드 (tabata, emom, amrap) + 카테고리 (bodyweight, fitness)

영문 `pushup` vs `push-up`: Apple은 별개 키워드로 처리하지 않음 (둘 다 매칭). 단수/복수만 분리됨.

### 日本語 (ja)

| 필드 | 내용 | 글자수 |
|------|------|--------|
| Name | `RepFlow: 腕立て 懸垂 カウンター` | 21자 |
| Subtitle | `Apple Watch GTG 自重トレーニング` | 24자 |
| Keywords | プッシュアップ,プルアップ,タバタ,EMOM,カリステニクス,筋トレ,自宅トレ,腹筋,胸筋,ホームジム | ~75자 |

논리:
- Name에서 한자(腕立て=팔굽혀펴기, 懸垂=턱걸이)로 일본어 사용자 검색 커버
- Keywords에서 영문 표기(プッシュアップ)로 영향 추가 커버

### 简体中文 (zh-Hans)

| 필드 | 내용 | 글자수 |
|------|------|--------|
| Name | `RepFlow: 俯卧撑 引体向上 计数器` | 19자 |
| Subtitle | `Apple Watch GTG 自重训练教练` | 21자 |
| Keywords | 健身,徒手训练,塔巴塔,间歇,腹肌,核心,胸肌,居家健身,运动追踪,训练记录 | ~55자 |

## 첫 3줄 (description preview) 룰

App Store 검색결과에서 사용자가 보는 영역 = **앱 제목 + 부제 + 설명 첫 3줄**.

설명 첫 3줄은 다음을 충족해야:
1. **Hook** (1줄): 사용자 문제 / 차별점 한 문장
2. **What** (1줄): 무슨 앱인지
3. **Why distinct** (1줄): 왜 다른 앱과 다른지

### 한국어 첫 3줄 (개선판)

```
헬스장 갈 필요 없다. 워치가 하루 종일 너의 코치다.

푸시업·풀업 자동 카운트 + 검증된 GTG (Grease the Groove) 훈련법을
워치에서 자동화. 진짜로 늘어나는 데일리 트레이닝.
```

### English (improved opening)

```
Don't need a gym. Your watch coaches you all day.

Auto-count push-ups & pull-ups + the proven GTG (Grease the Groove)
method, automated on your wrist. Daily training that actually grows you.
```

## 경쟁 분석 (vibe-check)

검색어로 타격할 만한 경쟁자:
- `Push Up Counter & Tracker` (id 6470828037) — 인기, 단순 카운터
- `LogReps` — 다양한 종목, 소셜
- `PushFit` — 프록시미티 센서
- `Train Fitness` — auto-detect 시도, 정확도 이슈

**우리 차별점이 키워드에 반영되어야:**
- "GTG" 단어 → 우리만 진지하게 채용
- "Grease the Groove" 풀텀 → niche지만 fitness geek 검색 수요

## 카테고리

- Primary: `HEALTH_AND_FITNESS`
- Secondary: `SPORTS`

서브카테고리는 강제 없음. Health & Fitness가 워치/카운터/캘리 모두 포괄.

## 가격 포지셔닝 (ASO에 연결)

App Store는 가격을 검색 ranking에 직접 반영하지 않으나, **무료 + IAP 구조가 다운로드 전환에 +30~50%**.
- Free download
- Pro 구독 (월/년/평생)
- 첫 100명 한정 가격 다운: 월 ₩1,900으로 출시 → 리뷰·랭킹 확보 후 정상가

## 리뷰 부스트 전략

ASO ranking은 리뷰 수·평점에 강하게 의존:
1. 핵심 운동 종료 후 리뷰 요청 (`SKStoreReviewController.requestReview`)
2. 5번째 운동 완료 시 1회 트리거 (만족도 정점)
3. 리뷰 요청 거부 시 자체 피드백 시트 → 부정 리뷰 방지

(코드 추가 필요 — 별도 task)

## 다음 액션 체크리스트

- [x] 4언어 metadata name/subtitle/keywords 재작성
- [x] 4언어 description 첫 3줄 hook 강화
- [x] Promotional text 다듬기
- [ ] 스크린샷 (snapshot 빌드 시뮬레이터 destination 이슈 해결 필요)
- [ ] 인앱 리뷰 요청 트리거 (`SKStoreReviewController`)
- [ ] App Preview 영상 (선택, 전환 +25~35%)
