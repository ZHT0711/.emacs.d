#include <SDKDDKVer.h>
#define UNICODE
#define NOMINMAX
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

#include <array>

constexpr auto PIPE_NAME = L"\\\\.\\pipe\\nn-draw-input";

auto main() -> int {
  auto pipe = CreateFileW(
    PIPE_NAME,
    GENERIC_READ,
    0,
    nullptr,
    OPEN_EXISTING,
    0,
    nullptr
  );
  if (pipe == INVALID_HANDLE_VALUE) return 1;

  auto mode = static_cast<DWORD>(PIPE_READMODE_BYTE);
  SetNamedPipeHandleState(pipe, &mode, nullptr, nullptr);

  auto buf     = std::array<char, 64>{};
  auto nread   = DWORD{};
  auto hStdout = GetStdHandle(STD_OUTPUT_HANDLE);
  while (ReadFile(pipe, buf.data(), buf.size(), &nread, nullptr) && nread > 0)
    WriteFile(hStdout, buf.data(), nread, nullptr, nullptr);

  CloseHandle(pipe);
  return 0;
}
