# Architecture & Design System

구현 세부 사항을 담는 문서입니다. 사용법은 [README.md](README.md) / [README.ko.md](README.ko.md) 를
보세요.

## 타깃 구성

| 타깃 | 역할 |
|---|---|
| `UsageCore` | 도메인 모델, API 클라이언트, SQLite 저장소, 인증, 설정 |
| `GlassUI` | Liquid Glass 디자인 시스템(토큰, 패널, 한도 행, 게이지, 버튼, 포매터) |
| `CommandCodeUsageBar` | 메뉴바 앱, 화면, 스케줄러, 알림 |
| `UsageCoreTestRunner` | 의존성 없는 자체 테스트 러너 |

`UsageCore` 는 UI 를 알지 못하고, `GlassUI` 는 `UsageCore` 를 알지 못합니다. 둘은 앱
타깃에서만 만납니다.

## API 계약

Command Code 내부(alpha) API 를 그대로 사용합니다.

| 용도 | 엔드포인트 |
|---|---|
| 계정 | `GET /alpha/whoami?limits=1` |
| 크레딧·한도 | `GET /alpha/billing/credits?orgId=` |
| 구독 | `GET /alpha/billing/subscriptions?orgId=` |
| 기간 요약 | `GET /alpha/usage/summary?orgId=&since=<currentPeriodStart>` |

인증은 `Authorization: Bearer <apiKey>` 이며 키는 `~/.commandcode/auth.json` 에서 읽습니다.
진짜 구현은 `/Applications/Command Code.app` 의 `out/main/index.js` 와
`node_modules/@commandcode/harness/dist/index.js` 를 보면 확인할 수 있습니다.

디코딩은 숫자/문자열을 모두 받는 느슨한 방식이라, 서버가 값의 형태를 바꾸어도
不至于 통째로 실패합니다. 응답이 아예 안 읽히면 마지막 스냅샷을 유지한 채
오류 상태를 표시합니다.

### 인증 방식 3가지

| 방식 | 설명 |
|---|---|
| `commandFile` | `~/.commandcode/auth.json` 직접 읽기(샌드박스 밖 기본값) |
| `selectedFile` | `NSOpenPanel` 로 고른 파일을 보안 범위 북마크로 저장(샌드박스 대응) |
| `manualKey` | 직접 입력한 키를 키체인(`kSecClassGenericPassword`)에 저장 |

## 누적 규칙

서버는 **현재 기간의 누적값만** 줍니다. 그래서 스냅샷을 로컬 SQLite 에 저장하고
직전 관측과의 차이를 일별·시간별로 누적합니다.

- 첫 관측(또는 결제 기간이 바뀐 직후)은 **baseline** → 증가분 0.
- 앱이 꺼져 있던 구간은 **재관측 시점의 증가분**으로 귀속됩니다.
- 서버 값(권위)과 로컬 관측값(추이)을 화면에서 구분해서 표시합니다.
- `daily_usage` / `hourly_usage` 는 `(키, period_start)` 로 적재해서 기간이 바뀌면
  같은 날짜라도 합쳐지지 않습니다.

DB: `~/Library/Application Support/CommandCodeUsageBar/usage.sqlite` (권한 `0600`).
보존 정책: raw 스냅샷 30일, 시간별 90일, 일별 2년(하루 1회 정리).

## 디자인 시스템 규칙

### 간격 스케일

`GlassTokens.Space` — 1 · 2 · 4 · 6 · 8 · 12 · 16 · 20 · 24 · 32 (4px 기본, 1-4-9 리듬).

### 간격 역할 (`GlassLayout`)

화면에서 숫자를 직접 쓰지 않고, “무엇 사이의 간격인가”로 이름을 붙인 역할로만
표현합니다.

| 역할 | 값 | 쓰이는 곳 |
|---|---|---|
| `screenPadding` | 16 | 팝오버 바깥 여백 |
| `panelPadding` | 16 | 한도 보드(유리 패널) 안쪽 여백 |
| `sectionGap` | 20 | 최상위 섹션 사이(헤더 · 한도 · 관측 · 조작) |
| `subSectionGap` | 16 | 한 섹션 안 하위 섹션 사이(관측값 · 추이) |
| `groupGap` | 12 | 같은 그룹 안 형제 요소 사이 |
| `panelRowGap` | 12 | 한도 보드 안 한도 행 사이 |
| `statGap` | 16 | 통계 값 열 사이 |
| `labelGap` | 4 | 라벨 ↔ 값, 카드 내부 행 사이 |
| `valueGap` | 4 | 큰 값 ↔ 상한 |
| `inlineGap` | 2 | 인라인 아이콘 ↔ 텍스트 |
| `badgePadding*` | 8 / 4 | 배지 안쪽 여백 |
| `buttonPadding*` | 8 / 4 | 버튼 안쪽 여백 |
| `bannerPadding` | 12 | 배너 안쪽 여백 |
| `emptyStatePadding` | 24 | 빈 상태 여백 |

### 한도 보드의 해부

세 개의 한도(5시간 · 주간 · 월간)는 **하나의 유리 패널**에 모아 한 섹션으로 보여줍니다.
카드를 나란히 늘어놓으면 좁은 폭 때문에 제목이 잘리고, 서로 다른 섹션처럼 읽히므로
divider 로만 나눕니다.

```text
╭──────────────────────────────────────────╮
│ (96% 남음)  5시간 한도                    │
│              13.5 / 14 크레딧   4시간 후   │
│              ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬░░░░░░ │
│ ──────────────────────────────────────── │
│ 주간 한도                       87% 남음  │
│ 30.4 / 35                    6일 18시간 후 │
│ ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬ │
│ ──────────────────────────────────────── │
│ 월간 한도                       93% 남음  │
│ 65.4 / 70                       30일 남음 │
╰──────────────────────────────────────────╯
```

- 히어로는 원형 게이지가 퍼센트를 대신하고, 나머지 행은 헤더에 퍼센트를 둡니다.
- 퍼센트에는 항상 단위(“남음”)를 붙입니다. 색만으로 의미를 전달하지 않습니다.

### 글래스 규칙

- 글래스는 **떠 있는 컨트롤 레이어**에만 씁니다. 모든 요소를 유리로 만들지 않습니다.
- 유리는 항상 콘텐츠의 **배경 레이어**로 둡니다(콘텐츠가 유리 위로 가려지지 않게).
- `glassEffect` 는 레이아웃 모디파이어 **뒤에** 적용합니다.
- 형태는 기능 안에서 통일합니다(패널 18 · 히어로 22 · 컨트롤 알약).
- 상호작용 요소에만 `interactive` 를 씁니다.

### 버전 분기

`GlassStyle` 이 자체 타입이라 macOS 26 전용 `Glass` 를 노출하지 않습니다.

| macOS | 렌더링 |
|---|---|
| 26 이상 | `glassEffect` + `GlassButtonStyle` |
| 13 – 25 | `.ultraThinMaterial` + `.bordered` 버튼 |

`CCUB_FORCE_FALLBACK=1` 환경변수로 하위 버전 경로를 직접 확인할 수 있습니다.

## 배포

| 대상 | 경로 |
|---|---|
| 로컬 | `scripts/build-app.sh` → `dist/` |
| 설치 + 로그인 자동 실행 | `scripts/install.sh` → `~/Applications` + LaunchAgent |
| 유니버설(Intel/ARM) | `scripts/build-app.sh --universal` (lipo) |
| 서명 · notarization · zip/dmg | `scripts/release.sh` (Developer ID 필요) |
| GitHub Actions | 태그 push 시 릴리스 자동 생성 |

SwiftPM 의 멀티아크 빌드는 Xcode(가 필요하다)를 요구하므로, 아키텍처별로 따로 빌드한
뒤 `lipo` 로 합칩니다. 빌드 자체는 macOS 26 SDK 가 필요합니다(글래스 API 때문)하지만
배포 타깃은 macOS 13 입니다.
