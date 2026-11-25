// Moveable for Windows — Ctrl + Alt + Shift + 방향키로 현재 선택된(포그라운드) 창을 부드럽게 이동시키는 트레이 앱.
//
// 구조
//   - 메인 스레드: 트레이 아이콘, 메뉴, 저수준 키보드 훅(WH_KEYBOARD_LL)
//   - 이동 스레드: 키가 눌려 있는 동안 DwmFlush()로 화면 프레임에 맞춰 SetWindowPos 호출

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shellapi.h>
#include <dwmapi.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cwchar>
#include <initializer_list>

#include "resource.h"

namespace {

constexpr UINT WM_TRAY = WM_APP + 1;
constexpr UINT WM_SEND_MASK_KEY = WM_APP + 2;
constexpr UINT TRAY_ID = 1;
constexpr UINT IDM_SPEED_BASE = 100;
constexpr UINT IDM_STARTUP = 200;
constexpr UINT IDM_QUIT = 201;

// 아무 키에도 할당되지 않은 가상 키. Alt 를 뗄 때 메뉴 막대가 활성화되는 것을 막는 데 쓴다.
constexpr WORD VK_MASK_KEY = 0xE8;

constexpr wchar_t kAppName[] = L"Moveable";
constexpr wchar_t kRegKey[] = L"Software\\Moveable";
constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";

struct SpeedOption { const wchar_t* label; int pxPerSec; };
constexpr SpeedOption kSpeeds[] = {
    {L"느리게 (400 px/s)", 400},
    {L"보통 (800 px/s)", 800},
    {L"빠르게 (1400 px/s)", 1400},
    {L"아주 빠르게 (2200 px/s)", 2200},
};

enum Dir : int { kLeft = 1, kRight = 2, kUp = 4, kDown = 8 };

std::atomic<int> g_held{0};       // 눌려 있는 방향 비트마스크
std::atomic<int> g_speed{800};    // px/s
std::atomic<bool> g_quit{false};
HANDLE g_wake = nullptr;          // 이동 스레드 깨우기 (auto-reset)
HHOOK g_hook = nullptr;
HWND g_wnd = nullptr;
HINSTANCE g_inst = nullptr;
HICON g_icon = nullptr;
UINT g_taskbarCreated = 0;

// ---------------------------------------------------------------- 설정 저장

int LoadSpeed() {
    DWORD value = 0, size = sizeof(value);
    if (RegGetValueW(HKEY_CURRENT_USER, kRegKey, L"Speed", RRF_RT_REG_DWORD, nullptr, &value, &size) == ERROR_SUCCESS &&
        value >= 50 && value <= 10000) {
        return static_cast<int>(value);
    }
    return 800;
}

void SaveSpeed(int speed) {
    DWORD value = static_cast<DWORD>(speed);
    RegSetKeyValueW(HKEY_CURRENT_USER, kRegKey, L"Speed", REG_DWORD, &value, sizeof(value));
}

bool IsStartupEnabled() {
    return RegGetValueW(HKEY_CURRENT_USER, kRunKey, kAppName, RRF_RT_REG_SZ, nullptr, nullptr, nullptr) == ERROR_SUCCESS;
}

void SetStartupEnabled(bool enable) {
    if (enable) {
        wchar_t path[MAX_PATH];
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        wchar_t quoted[MAX_PATH + 2];
        swprintf(quoted, MAX_PATH + 2, L"\"%s\"", path);
        RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, kAppName, REG_SZ, quoted,
                        static_cast<DWORD>((wcslen(quoted) + 1) * sizeof(wchar_t)));
    } else {
        RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kAppName);
    }
}

// ---------------------------------------------------------------- 창 이동

HWND TargetWindow() {
    HWND h = GetForegroundWindow();
    if (!h) return nullptr;
    h = GetAncestor(h, GA_ROOT);
    if (!h || !IsWindowVisible(h) || IsIconic(h) || IsZoomed(h)) return nullptr;

    wchar_t cls[64] = {};
    GetClassNameW(h, cls, 64);
    for (const wchar_t* shell : {L"Progman", L"WorkerW", L"Shell_TrayWnd", L"Shell_SecondaryTrayWnd"}) {
        if (wcscmp(cls, shell) == 0) return nullptr;  // 바탕화면·작업 표시줄은 제외
    }
    if (IsHungAppWindow(h)) return nullptr;
    return h;
}

DWORD WINAPI MoverThread(LPVOID) {
    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);

    while (!g_quit.load()) {
        WaitForSingleObject(g_wake, INFINITE);
        if (g_quit.load()) break;
        if (g_held.load() == 0) continue;

        HWND hwnd = TargetWindow();
        RECT rc;
        if (!hwnd || !GetWindowRect(hwnd, &rc)) {
            g_held.store(0);
            continue;
        }
        double x = rc.left, y = rc.top;

        LARGE_INTEGER last;
        QueryPerformanceCounter(&last);

        while (!g_quit.load()) {
            if (g_held.load() == 0) break;

            // 다음 화면 갱신까지 대기 → 모니터 주사율에 맞춰 부드럽게 이동
            if (FAILED(DwmFlush())) Sleep(8);

            LARGE_INTEGER now;
            QueryPerformanceCounter(&now);
            double dt = static_cast<double>(now.QuadPart - last.QuadPart) / static_cast<double>(freq.QuadPart);
            dt = std::min(dt, 0.05);  // 한 프레임이 밀려도 크게 튀지 않도록
            last = now;

            const int h = g_held.load();
            if (h == 0) break;
            const double dx = ((h & kRight) ? 1.0 : 0.0) - ((h & kLeft) ? 1.0 : 0.0);
            const double dy = ((h & kDown) ? 1.0 : 0.0) - ((h & kUp) ? 1.0 : 0.0);
            const double len = std::sqrt(dx * dx + dy * dy);
            if (len == 0.0) continue;  // 좌+우 동시 등 상쇄

            const double step = g_speed.load() * dt / len;
            x += dx * step;
            y += dy * step;

            if (!IsWindow(hwnd)) {
                g_held.store(0);
                break;
            }
            SetWindowPos(hwnd, nullptr, static_cast<int>(std::lround(x)), static_cast<int>(std::lround(y)), 0, 0,
                         SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOACTIVATE);
        }
    }
    return 0;
}

// ---------------------------------------------------------------- 키보드 훅

int DirFromVk(DWORD vk) {
    switch (vk) {
        case VK_LEFT: return kLeft;
        case VK_RIGHT: return kRight;
        case VK_UP: return kUp;
        case VK_DOWN: return kDown;
        default: return 0;
    }
}

bool IsDown(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

bool ComboHeld() {
    return IsDown(VK_CONTROL) && IsDown(VK_MENU) && IsDown(VK_SHIFT) && !IsDown(VK_LWIN) && !IsDown(VK_RWIN);
}

bool IsModifier(DWORD vk) {
    switch (vk) {
        case VK_CONTROL: case VK_LCONTROL: case VK_RCONTROL:
        case VK_MENU: case VK_LMENU: case VK_RMENU:
        case VK_SHIFT: case VK_LSHIFT: case VK_RSHIFT:
            return true;
        default:
            return false;
    }
}

LRESULT CALLBACK KeyboardProc(int code, WPARAM wParam, LPARAM lParam) {
    if (code == HC_ACTION) {
        const auto* k = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lParam);
        if (!(k->flags & LLKHF_INJECTED)) {
            const bool down = (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN);
            const int dir = DirFromVk(k->vkCode);

            if (dir != 0) {
                if (down && ComboHeld()) {
                    const int prev = g_held.fetch_or(dir);
                    if (prev == 0) {
                        SetEvent(g_wake);
                        PostMessageW(g_wnd, WM_SEND_MASK_KEY, 0, 0);
                    }
                    return 1;  // 단축키는 앱으로 전달하지 않음 (자동 반복 포함)
                }
                if (!down && (g_held.load() & dir)) {
                    g_held.fetch_and(~dir);
                    return 1;
                }
            } else if (!down && IsModifier(k->vkCode) && g_held.load() != 0) {
                g_held.store(0);  // 수정키 중 하나라도 떼면 즉시 멈춤
            }
        }
    }
    return CallNextHookEx(g_hook, code, wParam, lParam);
}

void SendMaskKey() {
    INPUT in[2] = {};
    in[0].type = INPUT_KEYBOARD;
    in[0].ki.wVk = VK_MASK_KEY;
    in[1] = in[0];
    in[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(2, in, sizeof(INPUT));
}

// ---------------------------------------------------------------- 트레이

void AddTrayIcon(bool showBalloon) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(nid);
    nid.hWnd = g_wnd;
    nid.uID = TRAY_ID;
    nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    nid.uCallbackMessage = WM_TRAY;
    nid.hIcon = g_icon;
    wcscpy_s(nid.szTip, L"Moveable — Ctrl+Alt+Shift+방향키로 창 이동");
    if (showBalloon) {
        nid.uFlags |= NIF_INFO;
        wcscpy_s(nid.szInfoTitle, L"Moveable 실행 중");
        wcscpy_s(nid.szInfo, L"Ctrl + Alt + Shift + 방향키로 선택된 창을 옮길 수 있어요.");
        nid.dwInfoFlags = NIIF_NONE;
    }
    Shell_NotifyIconW(NIM_ADD, &nid);
}

void RemoveTrayIcon() {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(nid);
    nid.hWnd = g_wnd;
    nid.uID = TRAY_ID;
    Shell_NotifyIconW(NIM_DELETE, &nid);
}

void ShowTrayMenu() {
    HMENU menu = CreatePopupMenu();
    AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, L"Ctrl + Alt + Shift + 방향키: 선택된 창 이동");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, L"이동 속도");
    for (UINT i = 0; i < ARRAYSIZE(kSpeeds); ++i) {
        UINT flags = MF_STRING | (kSpeeds[i].pxPerSec == g_speed.load() ? MF_CHECKED : MF_UNCHECKED);
        AppendMenuW(menu, flags, IDM_SPEED_BASE + i, kSpeeds[i].label);
    }
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING | (IsStartupEnabled() ? MF_CHECKED : MF_UNCHECKED), IDM_STARTUP,
                L"Windows 시작 시 자동 실행");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, IDM_QUIT, L"Moveable 종료");

    POINT pt;
    GetCursorPos(&pt);
    SetForegroundWindow(g_wnd);  // 메뉴 바깥을 클릭하면 닫히도록
    TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, pt.x, pt.y, 0, g_wnd, nullptr);
    PostMessageW(g_wnd, WM_NULL, 0, 0);
    DestroyMenu(menu);
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == g_taskbarCreated && g_taskbarCreated != 0) {
        AddTrayIcon(false);  // 탐색기가 다시 시작되면 아이콘 복구
        return 0;
    }
    switch (msg) {
        case WM_TRAY:
            if (LOWORD(lParam) == WM_RBUTTONUP || LOWORD(lParam) == WM_LBUTTONUP || LOWORD(lParam) == WM_CONTEXTMENU) {
                ShowTrayMenu();
            }
            return 0;
        case WM_SEND_MASK_KEY:
            SendMaskKey();
            return 0;
        case WM_COMMAND: {
            const UINT id = LOWORD(wParam);
            if (id >= IDM_SPEED_BASE && id < IDM_SPEED_BASE + ARRAYSIZE(kSpeeds)) {
                g_speed.store(kSpeeds[id - IDM_SPEED_BASE].pxPerSec);
                SaveSpeed(g_speed.load());
            } else if (id == IDM_STARTUP) {
                SetStartupEnabled(!IsStartupEnabled());
            } else if (id == IDM_QUIT) {
                DestroyWindow(hwnd);
            }
            return 0;
        }
        case WM_DESTROY:
            RemoveTrayIcon();
            PostQuitMessage(0);
            return 0;
        default:
            return DefWindowProcW(hwnd, msg, wParam, lParam);
    }
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\MoveableSingleInstance");
    if (GetLastError() == ERROR_ALREADY_EXISTS) {
        MessageBoxW(nullptr, L"Moveable이 이미 실행 중입니다. 작업 표시줄 트레이 아이콘을 확인하세요.", kAppName,
                    MB_OK | MB_ICONINFORMATION);
        return 0;
    }

    // 모니터별 DPI 인식 → 실제 픽셀 단위로 정확하게 이동
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    g_inst = instance;
    g_speed.store(LoadSpeed());
    g_icon = static_cast<HICON>(LoadImageW(instance, MAKEINTRESOURCEW(IDI_APP), IMAGE_ICON,
                                           GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0));
    if (!g_icon) g_icon = LoadIconW(nullptr, IDI_APPLICATION);

    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = instance;
    wc.lpszClassName = L"MoveableHiddenWindow";
    wc.hIcon = g_icon;
    RegisterClassExW(&wc);
    g_wnd = CreateWindowExW(0, wc.lpszClassName, kAppName, 0, 0, 0, 0, 0, nullptr, nullptr, instance, nullptr);
    g_taskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");

    g_wake = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    HANDLE mover = CreateThread(nullptr, 0, MoverThread, nullptr, 0, nullptr);
    if (mover) SetThreadPriority(mover, THREAD_PRIORITY_ABOVE_NORMAL);

    g_hook = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardProc, instance, 0);
    if (!g_hook) {
        MessageBoxW(nullptr, L"키보드 단축키를 등록하지 못했습니다.", kAppName, MB_OK | MB_ICONERROR);
        return 1;
    }

    AddTrayIcon(true);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    UnhookWindowsHookEx(g_hook);
    g_quit.store(true);
    g_held.store(0);
    SetEvent(g_wake);
    if (mover) {
        WaitForSingleObject(mover, 2000);
        CloseHandle(mover);
    }
    CloseHandle(g_wake);
    if (mutex) {
        ReleaseMutex(mutex);
        CloseHandle(mutex);
    }
    return 0;
}
