# RepFlow Design System

> Linear.app의 ultra-minimal, precise, 고밀도 미학 + RepFlow의 오렌지 액센트.

## 원칙

1. **Density first** — 공간을 낭비하지 않음. 한 화면에 의미 있는 정보가 빽빽하게.
2. **Crisp typography** — 헤딩은 tight letter spacing, 숫자는 monospaced.
3. **Monochromatic with single accent** — 베이스는 다크/그레이 톤, 오렌지 단일 액센트.
4. **Subtle borders** — `rgba(white, 0.06~0.10)`. 절대 두꺼운 라인 사용 안 함.
5. **Hierarchy via opacity** — 여러 그레이 단계 대신 white의 opacity (1.0 / 0.6 / 0.4) 사용.
6. **Pixel-perfect alignment** — 4pt grid 엄격 준수.
7. **Motion subtle** — 150–250ms ease-in-out. 절대 bouncy 안 됨.

## 토큰

### 색상

```swift
// Background layers (다크 우선)
RFColor.bg          = #0B0B0E       // App root
RFColor.bgElevated  = #131318       // Card/sheet
RFColor.bgSubtle    = #1A1A20       // Hover/selected

// Border
RFColor.border      = white @ 0.08
RFColor.borderStrong= white @ 0.14

// Text
RFColor.fg          = white
RFColor.fgMuted     = white @ 0.62
RFColor.fgSubtle    = white @ 0.42

// Accent (RepFlow brand — 오렌지/마젠타)
RFColor.accent      = #FF6B14       // Primary CTA, focus
RFColor.accentSoft  = #FF6B14 @ 0.12
RFColor.success     = #2DD4A4
RFColor.warning     = #F0B429
RFColor.danger      = #E5484D
```

라이트 모드는 다크의 inversion (배경 흰색, 텍스트 검정). 단 Linear는 다크가 default — 우리도 다크 우선.

### Typography

SF Pro 시스템 폰트. tight tracking (-0.5 ~ -1.0).

```
display.lg   34pt / .heavy  / -0.8 tracking   (영웅 카운트)
display.md   28pt / .bold   / -0.5
title.lg     22pt / .bold   / -0.3
title.md     17pt / .semibold
body         15pt / .regular
caption      13pt / .regular / +0.0
caption.sm   11pt / .medium  / +0.2

mono.lg      28pt / .bold .monospacedDigit   (rep 카운터)
mono.body    14pt / .medium .monospacedDigit (시간/숫자)
```

### Spacing scale (4pt grid)

```
xs   = 4
sm   = 8
md   = 12
lg   = 16
xl   = 24
xxl  = 32
xxxl = 48
```

### Radius

```
xs = 4   (chips)
sm = 6   (buttons)
md = 10  (cards)
lg = 14  (sheets, modals)
xl = 20  (hero cards)
```

### Shadows (sparingly)

Linear style — shadow는 sheet/modal에만, 그 외 elevation은 background tint로.

```
sheet.shadow = 0 12 32  rgba(0,0,0,0.45)
```

## 컴포넌트 패턴

- **Card**: `bgElevated` + 1px `border` + radius `md`
- **Pill / Chip**: `accentSoft` bg + `accent` text, font `.caption.sm`
- **CTA primary**: `accent` solid + white text, radius `sm`, height 44
- **CTA secondary**: `bgSubtle` + `border` + white text
- **Tab/Section header**: `caption.sm` + `fgMuted` + 8pt 위 패딩
- **Number display**: `.mono.lg` with `contentTransition(.numericText())`
- **Toggle row**: 14pt body label + 13pt caption desc, system Toggle (tinted accent)

## Watch 적응

워치는 38–49mm 화면 — 위 토큰을 ~60% 스케일로:
- Display 56pt (rep 카운터)
- Body 13pt
- Spacing 절반 (xs=2, sm=4, md=6, lg=8)
- Card 사용 안 함 — 그냥 surface에 직접 stack

## DO / DON'T

✅ DO:
- 빈 공간을 정보 밀도로 채워라 (빈 카드 X)
- 모든 숫자는 monospaced
- 활성 상태는 색이 아닌 opacity 변화로 표현
- 사용자가 한 화면에서 90%의 작업을 완료할 수 있게

❌ DON'T:
- 무지개 그라데이션 (오직 단조로운 그라데이션만)
- bouncy/spring 애니메이션 (subtle, fast만)
- emoji, illustration (아이콘은 SF Symbols만)
- 그림자 남발
- 5개 이상의 그레이 톤 (4단계만: 100/60/40/20)
