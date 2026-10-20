<div align="center">
  <img src="docs/screenshot.png" width="420" alt="Command Code Usage Bar 팝오버 화면">
  <h1>Command Code Usage Bar</h1>
  <p>Command Code 플랜 사용량을 맥 상단바에서 실시간으로 확인하는 메뉴바 앱</p>
</div>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="#설치">설치</a> ·
  <a href="#무엇을-보여주나요">화면</a> ·
  <a href="#동작-원리">동작 원리</a> ·
  <a href="#개인정보">개인정보</a>
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-000000">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138">
  <img alt="License MIT" src="https://img.shields.io/badge/license-MIT-2ea44f">
  <a href="https://github.com/jhparkdev/commandcode-usage-bar/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/jhparkdev/commandcode-usage-bar?label=release">
  </a>
  <a href="https://github.com/jhparkdev/commandcode-usage-bar/actions/workflows/ci.yml">
    <img alt="CI" src="https://github.com/jhparkdev/commandcode-usage-bar/actions/workflows/ci.yml/badge.svg">
  </a>
</p>

---

## 왜 필요한가

플랜 한도는 브라우저 탭에 숨어 있고, 다시 떠올리기 번거롭습니다. 사용량은 **일하는
동안에** 보이는 숫자입니다.

Command Code Usage Bar는 상단바에 필요한 숫자 세 개만 남기고, 그것을 실제로 볼 수 있는
히스토리로 바꿉니다.

## 무엇을 보여주나요

모든 값은 **사용량이 아니라 남은량** 기준입니다. 중요한 건 "얼마나 썼나"가 아니라
"얼마나 남았나"이기 때문입니다.

| 패널 | 표시 | 초기화 주기 |
|---|---|---|
| **5시간 한도** | 남은 크레딧, 상한, 남은 %, 초기화까지 | 5시간 롤링 |
| **주간 한도** | 남은 크레딧, 상한, 남은 %, 초기화까지 | 7일 롤링 |
| **월간 한도** | 남은 크레딧, 상한, 남은 %, 남은 일수 | 결제 기간 |
| **오늘** | 크레딧, 요청 수, 입력/출력 토큰(로컬 관측) | 일 |
| **최근 7일** | 일별 크레딧 사용 추이 | — |

상단바 항목은 설정에서 고른 한도를 그대로 보여주고, 남은 양이 줄어갈수록 색이 바뀝니다.

## 설치

**macOS 13 이상** 필요합니다(Intel x86_64 · Apple Silicon arm64 모두 지원).

1. [Releases](https://github.com/jhparkdev/commandcode-usage-bar/releases) 에서 최신 `.dmg` 또는 `.zip` 을 받습니다.
2. 앱을 `Applications` 로 옮깁니다.
3. 실행하면 상단바에 나타납니다. Dock 아이콘도, 창도 없습니다.
4. Command Code 데스크톱 앱에 로그인되어 있어야 합니다.

```bash
curl -LO https://github.com/jhparkdev/commandcode-usage-bar/releases/latest/download/Command.Code.Usage.Bar-0.1.0-universal.dmg
hdiutil attach "Command.Code.Usage.Bar-0.1.0-universal.dmg"
cp -R "/Volumes/Command Code Usage Bar/Command Code Usage Bar.app" ~/Applications/
hdiutil detach "/Volumes/Command Code Usage Bar"
```

> 릴리스 빌드는 Developer ID 서명이 없습니다. 첫 실행 때 macOS 가 확인을 요구하면
> **우클릭 → 열기** 를 누르세요.

## 동작 원리

1. **인증** — 로컬에 있는 Command Code 세션(`~/.commandcode/auth.json`)에서 API 키를
   읽고 메모리에만 유지합니다.
2. **조회** — Command Code 데스크톱 앱이 쓰는 것과 같은 엔드포인트
   (`/alpha/whoami`, `/alpha/billing/credits`, `/alpha/billing/subscriptions`,
   `/alpha/usage/summary`)를 60초마다 호출하고, 잠에서 깨어나면 바로 갱신합니다.
3. **누적** — 서버는 현재 기간의 합계만 주므로, 스냅샷을 로컬 SQLite 에 쓰고
   관측 사이의 차이를 일별·시간별 히스토리로 만듭니다. 기간의 첫 관측은 기준점
   (baseline)이라 설치 전 사용량을 오늘 사용량으로 잘못 잡지 않습니다.
4. **표시** — SwiftUI `MenuBarExtra` 로 상단바에 내보내고, macOS 26 의 Liquid Glass
   디자인 언어로 그립니다.

`api.commandcode.ai` 이외로 나가는 요청은 없습니다.

## 설정

| 항목 | 선택지 |
|---|---|
| 갱신 간격 | 30초 / 60초 / 120초 / 300초 |
| 상단바 표시 | 5시간 한도 / 주간 한도 / 월간 한도 |
| 알림 | 남은 20% · 5% 이하 시 |
| 로그인 시 자동 실행 | 켜기 / 끄기 |
| 인증 | 로컬 세션 파일 / 사용자가 고른 파일 / 직접 입력한 API 키 |

## 개발

```bash
git clone https://github.com/jhparkdev/commandcode-usage-bar.git
cd commandcode-usage-bar

swift run UsageCoreTestRunner      # 테스트
./scripts/build-app.sh --run       # 현재 아키텍처로 빌드·실행
./scripts/build-app.sh --universal # arm64 + x86_64
```

Xcode 프로젝트 없이 순수 SwiftPM 으로, 외부 의존성 없이 구성했습니다. 타깃은 세 개입니다.

| 타것 | 역할 |
|---|---|
| `UsageCore` | 도메인 모델, API 클라이언트, SQLite 저장소, 인증 |
| `GlassUI` | Liquid Glass 디자인 시스템(토큰 · 패널 · 게이지 · 버튼) |
| `CommandCodeUsageBar` | 메뉴바 앱과 화면 |

## 호환성

| macOS | 표현 |
|---|---|
| 26 이상 | 네이티브 Liquid Glass(`glassEffect`, 글래스 버튼 스타일) |
| 13 – 25 | 재질(material) 기반 폴백. 레이아웃과 지표는 동일 |

빌드는 macOS 26 SDK 기준으로 하지만 배포 타깃은 macOS 13 이라, 새 글래스 화면과 옛
재질 화면이 같은 디자인 토큰에서 나옵니다.

## 개인정보

- API 키는 디스크에서 읽어 메모리에만 두며, 디스크·로그·`UserDefaults` 에 남기지
  않습니다. 직접 입력한 키는 macOS 키체인에만 저장됩니다.
- 사용량 수치는 이 기기 안에만 있습니다
  (`~/Library/Application Support/CommandCodeUsageBar/usage.sqlite`, 권한 `0600`).
- 텔레메트리·분석 도구·크rash 리포팅이 없습니다.

## 기여하기

이슈와 PR 을 환영합니다. 디자인 시스템은 `GlassUI` 에서 일관되게 유지해 주세요
(간격은 임의 숫자가 아니라 `GlassLayout` 역할로 표현)하고, 동작을 바꾸면 테스트를
함께 추가해 주세요(`swift run UsageCoreTestRunner`).

구현 세부 사항은 [docs/architecture.md](docs/architecture.md) 에 정리했습니다.
API 계약, 누적 규칙, 간격 시스템, 배포 파이프라인을 담고 있습니다.

## 라이선스

MIT — [LICENSE](LICENSE)
