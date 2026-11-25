# Moveable

키보드 단축키로 지금 선택된 창을 부드럽게 **이동**하고 **크기 조절**하는 작은 앱입니다. **macOS**와 **Windows**를 지원합니다.

| | 창 이동 | 창 크기 조절 |
|---|---|---|
| macOS | **⌃ Control + ⌥ Option + ⇧ Shift + 방향키** | **⌥ Option + ⇧ Shift + 방향키** |
| Windows | **Ctrl + Alt + Shift + 방향키** | **Alt + Shift + 방향키** |

창을 하나하나 마우스로 끌어 옮기기 귀찮을 때 쓰세요. Cmd+Tab·Alt+Tab이나 클릭으로 창을 고르고 단축키를 누르고 있으면 일정한 속도로 쭉 움직입니다.

크기 조절은 **왼쪽 위 꼭지점이 고정**됩니다. → 넓어짐, ← 좁아짐, ↓ 길어짐, ↑ 짧아짐. 크기를 줄인 다음 이동 단축키로 원하는 곳에 옮기면 됩니다.

*A tiny macOS / Windows utility that glides the focused window around (Ctrl+Option/Alt+Shift + arrows) and resizes it from its top-left corner (Option/Alt+Shift + arrows) at a constant speed.*

## 기능

- 누르고 있는 동안 포커스된 창이 일정한 속도로 이동 / 크기 조절
- 방향키 두 개를 같이 누르면 대각선으로 이동·조절 (속도는 동일)
- 방향키나 수정키 중 하나라도 떼면 즉시 정지
- 메뉴바 / 트레이 메뉴에서 속도 선택: 400 / 800 / 1400 / 2200 px/s
- 크기 조절 단축키 켜기/끄기 (다른 앱 단축키와 겹칠 때)
- 로그인(시작) 시 자동 실행 옵션
- 외부 의존성 없음 — macOS는 Swift 파일 하나, Windows는 C++ 파일 하나

## 다운로드

### 👉 [neil-jung.github.io/moveable](https://neil-jung.github.io/moveable/)

랜딩 페이지에서 내 운영체제에 맞는 설치 프로그램을 바로 받을 수 있습니다. [Releases](../../releases/latest)에서 직접 받아도 됩니다.

| | 설치 프로그램 (권장) | 설치 없이 쓰기 |
|---|---|---|
| macOS | `Moveable.pkg` | `Moveable.zip` |
| Windows | `Moveable-Setup.exe` | `Moveable-Windows-x64.zip` |

---

## macOS

### 설치 (설치 프로그램)

1. `Moveable.pkg`를 엽니다. 개발자 서명이 없는 앱이라 "확인할 수 없음" 안내가 뜨면 **시스템 설정 → 개인정보 보호 및 보안** 아래쪽의 **그래도 열기**를 누르세요.
2. 설치를 진행하면 `응용 프로그램` 폴더에 설치되고 바로 실행됩니다.
3. **시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 **Moveable**을 켭니다. 1초 안에 자동으로 활성화됩니다.

업데이트할 때도 같은 방법으로 설치하면 됩니다. 설치 프로그램이 이전 버전을 종료하고 예전 권한 기록을 정리하니, 손쉬운 사용에서 Moveable만 다시 켜 주세요.

### 설치 (zip)

1. `Moveable.zip`을 받아 압축을 풀고 `Moveable.app`을 `응용 프로그램` 폴더로 옮깁니다.
2. 실행이 막히면 터미널에서 아래 명령으로 격리 속성을 지우거나, Finder에서 앱을 **우클릭 → 열기**를 선택하세요.
   ```bash
   xattr -dr com.apple.quarantine /Applications/Moveable.app
   ```
3. 실행 후 손쉬운 사용에서 **Moveable**을 켭니다.

### 직접 빌드

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

배포용 파일은 `./build.sh --release`로 `dist/Moveable.pkg`(설치 프로그램)와 `dist/Moveable.zip`에 만들어집니다. 버전은 저장소 루트의 `VERSION` 파일에서 읽습니다.

### 요구 사항

- macOS 13 Ventura 이상, Apple Silicon / Intel (유니버설 바이너리)
- 손쉬운 사용(Accessibility) 권한 — 다른 앱의 창 위치를 바꾸고 단축키를 받기 위해 필요합니다.

### 문제 해결

- **키를 눌러도 안 움직여요** — 메뉴바 아이콘에 "● 동작 중"이 보이는지 확인하세요. "권한 필요"라면 손쉬운 사용에서 Moveable을 켜세요.
- **다시 빌드했더니 안 돼요** — 서명 인증서 없이(ad-hoc) 서명한 앱이라 macOS는 새로 빌드할 때마다 다른 앱으로 봅니다. 손쉬운 사용 목록에서 Moveable을 지웠다가(−) 다시 켜거나 아래 명령으로 초기화한 뒤 앱을 다시 실행하세요.
  ```bash
  tccutil reset Accessibility local.moveable.app
  ```
- **일부 창은 안 움직여요** — 전체 화면 창이나 macOS가 위치 변경을 막는 창은 이동할 수 없습니다.
- **⌥⇧ + 방향키로 글자 선택이 안 돼요** — macOS에서 ⌥⇧ + ←/→는 단어 단위 선택 단축키입니다. Moveable이 크기 조절에 쓰는 동안에는 앱에 전달되지 않으니, 텍스트 선택이 필요하면 메뉴바 메뉴에서 **크기 조절 단축키 사용**을 끄세요.
- 권한 상태 로그는 `~/Library/Logs/Moveable.log`에 남습니다.

---

## Windows

### 설치 (설치 프로그램)

1. `Moveable-Setup.exe`를 실행합니다. 코드 서명이 없어서 **"Windows의 PC 보호"** 창이 뜰 수 있습니다. **추가 정보 → 실행**을 누르세요.
2. 관리자 권한 없이 내 계정(`%LOCALAPPDATA%\Programs\Moveable`)에 설치됩니다. 시작 메뉴 바로 가기가 생기고, **Windows 시작 시 자동 실행**을 고를 수 있습니다.
3. 작업 표시줄 오른쪽 트레이(필요하면 `^` 펼치기)에 파란 화살표 아이콘이 생기면 준비 완료입니다. 별도 권한 설정은 필요 없습니다.

지우려면 **설정 → 앱 → 설치된 앱**에서 Moveable을 제거하세요. 자동 실행과 설정도 함께 지워집니다.

### 설치 (zip)

`Moveable-Windows-x64.zip`을 풀어 `Moveable.exe`를 원하는 폴더에 두고 실행하면 됩니다.

트레이 아이콘을 클릭하면 속도 변경, **크기 조절 단축키 사용**, **Windows 시작 시 자동 실행**, 종료 메뉴가 나옵니다.

### 직접 빌드

Visual Studio 2022(“C++를 사용한 데스크톱 개발” 워크로드)와 CMake가 필요합니다.

```powershell
git clone https://github.com/Neil-Jung/moveable.git
cd moveable
cmake -S windows -B build -A x64
cmake --build build --config Release
```

결과물은 `build\Release\Moveable.exe`입니다. 런타임을 정적으로 링크해 exe 하나만 있으면 실행됩니다. 설치 프로그램은 [Inno Setup 6](https://jrsoftware.org/isinfo.php)으로 `iscc /DAppVersion=1.3.0 windows\installer.iss`를 실행하면 `dist\Moveable-Setup.exe`로 만들어집니다.

### 요구 사항

- Windows 10 (1703 이상) / Windows 11, x64 (ARM PC에서는 x64 에뮬레이션으로 동작)

### 문제 해결

- **일부 창은 안 움직여요** — 관리자 권한으로 실행된 창(작업 관리자, 관리자 명령 프롬프트 등)은 일반 권한의 Moveable이 옮길 수 없습니다. 그런 창도 옮기려면 Moveable을 **관리자 권한으로 실행**하세요. 최대화되거나 최소화된 창도 이동·크기 조절하지 않습니다.
- **단축키가 다른 프로그램과 겹쳐요** — Moveable이 실행 중일 때는 Ctrl+Alt+Shift+방향키와 Alt+Shift+방향키가 다른 앱에 전달되지 않습니다. VS Code 등에서 Alt+Shift+방향키(줄 복사·선택 확장)를 써야 하면 트레이 메뉴에서 **크기 조절 단축키 사용**을 끄세요. Alt+Shift로 입력 언어를 바꾸는 설정을 쓰더라도 크기 조절 중에는 언어가 바뀌지 않도록 처리돼 있습니다.

---

## 동작 방식

- **macOS**: `CGEventTap`으로 단축키를 가로채고, 맨 앞 앱의 포커스된 창(`AXFocusedWindow`)을 120Hz 타이머로 경과 시간 × 속도만큼 `AXPosition`(이동) 또는 `AXSize`(크기)를 갱신합니다. Chrome·Electron 계열은 이동 중에만 `AXEnhancedUserInterface`를 잠시 꺼서 버벅임을 없앱니다.
- **Windows**: 저수준 키보드 훅(`WH_KEYBOARD_LL`)으로 단축키를 가로채고, 별도 스레드에서 `DwmFlush()`로 화면 주사율에 맞춰 `SetWindowPos`로 위치나 크기를 바꿉니다. Alt를 뗄 때 메뉴 막대가 열리지 않도록 할당되지 않은 키를 한 번 보냅니다.

두 버전 모두 단축키는 앱에 전달하지 않으며, 프레임이 밀려도 실제 경과 시간 기준으로 계산하므로 속도가 일정합니다. 앱이 정한 최소·최대 크기에 막히면 실제 크기를 따라가므로 반대 방향으로 누르면 바로 반응합니다.

## 라이선스

[MIT](LICENSE)
