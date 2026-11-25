# Moveable

**⌃ Control + ⌥ Option + ⇧ Shift + 방향키**로 지금 선택된 창을 부드럽게 미끄러지듯 옮기는 macOS 메뉴바 앱입니다.

창을 하나하나 마우스로 끌어 옮기기 귀찮을 때, Cmd+Tab이나 클릭으로 창을 고르고 키를 누르고 있으면 일정한 속도로 쭉 이동합니다.

*A tiny macOS menu bar app that glides the focused window around at a constant speed while you hold ⌃⌥⇧ + arrow keys.*

## 기능

- **⌃⌥⇧ + ← ↑ → ↓**: 누르고 있는 동안 포커스된 창이 일정한 속도로 이동
- 방향키 두 개를 같이 누르면 대각선 이동 (속도는 동일)
- 방향키나 수정키 중 하나라도 떼면 즉시 정지
- 메뉴바에서 속도 선택: 400 / 800 / 1400 / 2200 px/s
- 로그인 시 자동 실행 옵션
- Chrome · Electron 계열 앱에서도 버벅이지 않도록 이동 중에만 `AXEnhancedUserInterface`를 잠시 끔
- Dock 아이콘 없음, 메뉴바에만 표시
- 외부 의존성 없는 Swift 파일 하나

## 설치

### 방법 1: 릴리스 다운로드

1. [Releases](../../releases)에서 `Moveable.zip`을 받아 압축을 풀고 `Moveable.app`을 `응용 프로그램` 폴더로 옮깁니다.
2. 개발자 서명이 없는 앱이라 처음엔 macOS가 실행을 막습니다. 터미널에서 아래 명령으로 격리 속성을 지우거나,
   ```bash
   xattr -dr com.apple.quarantine /Applications/Moveable.app
   ```
   Finder에서 앱을 **우클릭 → 열기**를 선택하세요. (최신 macOS에서는 *시스템 설정 → 개인정보 보호 및 보안*에서 "그래도 열기"를 눌러야 할 수 있습니다.)
3. 실행 후 **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 **Moveable**을 켭니다. 1초 안에 자동으로 활성화됩니다.

### 방법 2: 직접 빌드

Xcode 또는 Command Line Tools(`xcode-select --install`)가 필요합니다.

```bash
git clone https://github.com/Neil-Jung/moveable.git
cd moveable
./build.sh
```

`Moveable.app`이 만들어지고 바로 실행됩니다. 직접 빌드한 앱에는 격리 속성이 없으므로 위의 `xattr` 명령은 필요 없습니다. 실행 후 손쉬운 사용에서 Moveable을 켜세요.

`응용 프로그램` 폴더에 두고 쓰려면 (로그인 시 자동 실행도 이쪽이 안정적입니다):

```bash
pkill -f MacOS/Moveable; ditto Moveable.app /Applications/Moveable.app && open /Applications/Moveable.app
```

옮긴 뒤 단축키가 안 먹으면 손쉬운 사용 목록에서 Moveable을 껐다 켜세요.

배포용 zip은 `./build.sh --release`로 `dist/Moveable.zip`에 만들어집니다.

## 요구 사항

- macOS 13 Ventura 이상
- Apple Silicon / Intel 모두 지원 (유니버설 바이너리)
- 손쉬운 사용(Accessibility) 권한 — 다른 앱의 창 위치를 바꾸고 단축키를 받기 위해 필요합니다.

## 문제 해결

- **키를 눌러도 안 움직여요** — 메뉴바 아이콘에 "● 동작 중"이 보이는지 확인하세요. "권한 필요"라면 손쉬운 사용에서 Moveable을 켜세요.
- **다시 빌드했더니 안 돼요** — 서명 인증서 없이(ad-hoc) 서명한 앱이라 macOS는 새로 빌드할 때마다 다른 앱으로 봅니다. 손쉬운 사용 목록에서 Moveable을 지웠다가(−) 다시 켜거나 아래 명령으로 초기화한 뒤 앱을 다시 실행하세요.
  ```bash
  tccutil reset Accessibility local.moveable.app
  ```
- **일부 창은 안 움직여요** — 전체 화면 창이나 macOS가 위치 변경을 막는 창은 이동할 수 없습니다.
- 권한 상태 로그는 `~/Library/Logs/Moveable.log`에 남습니다.

## 동작 방식

- `CGEventTap`으로 ⌃⌥⇧ + 방향키 입력을 가로채고(앱에는 전달하지 않음), 키를 떼거나 수정키가 풀리면 멈춥니다.
- 이동을 시작할 때 맨 앞 앱의 포커스된 창(`AXFocusedWindow`)을 한 번 잡고, 120Hz 타이머로 경과 시간 × 속도만큼 `AXPosition`을 갱신합니다. 프레임이 밀려도 속도가 일정합니다.

## 라이선스

[MIT](LICENSE)
