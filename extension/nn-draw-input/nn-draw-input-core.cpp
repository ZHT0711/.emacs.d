int plugin_is_GPL_compatible;
#include "emacs-module.h"

#include <SDKDDKVer.h>
#define UNICODE
#define NOMINMAX
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <imm.h>

#include <array>

using std::array;

constexpr auto IME_COMP_SIZE = 64;
constexpr auto PIPE_BUF_SIZE = IME_COMP_SIZE * 2;
constexpr auto PIPE_NAME     = L"\\\\.\\pipe\\nn-draw-input";

static auto wideToUtf8(const wchar_t* wstr, int wcount, char* out, int outSize) -> int {
  out[0]    = '\0';
  auto ulen = WideCharToMultiByte(CP_UTF8, 0, wstr, wcount, out, outSize - 1, nullptr, nullptr);
  return ulen > 0 ? (out[ulen] = '\0', ulen) : 0;
}

class ImeMonitor {
public:
  static auto instance(emacs_env* env) -> ImeMonitor& {
    static auto monitor = ImeMonitor{env};
    return monitor;
  }

private:
  using emacsFn = emacs_value (*)(emacs_env*, ptrdiff_t, emacs_value*, void*) EMACS_NOEXCEPT;

  HWND    window_      = nullptr;
  WNDPROC origWndProc_ = nullptr;
  HANDLE  pipe_        = INVALID_HANDLE_VALUE;

  array<char, IME_COMP_SIZE> composition_ = {};

  static auto defun(
    emacs_env*  env,
    const char* name,
    emacsFn     fn,
    ptrdiff_t   minargs,
    ptrdiff_t   maxargs,
    const char* doc
  ) -> void {
    auto args = array{
      env->intern(env, name),
      env->make_function(env, minargs, maxargs, fn, doc, nullptr)
    };
    env->funcall(env, env->intern(env, "fset"), 2, args.data());
  }

  static auto eBegin(emacs_env* e, ptrdiff_t, emacs_value* args, void*) EMACS_NOEXCEPT {
    return instance(e).begin(e, reinterpret_cast<HWND>(e->extract_integer(e, args[0])));
  }

  static auto eEnd(emacs_env* e, ptrdiff_t, emacs_value*, void*) EMACS_NOEXCEPT {
    instance(e).end();
    return e->intern(e, "t");
  }

  static auto eShutdown(emacs_env* e, ptrdiff_t, emacs_value*, void*) EMACS_NOEXCEPT {
    instance(e).shutdown();
    return e->intern(e, "t");
  }

  ImeMonitor(emacs_env* env) {
    defun(env, "nn-ime-begin", eBegin, 1, 1, "Begin IME with WINDOW-ID.");
    defun(env, "nn-ime-end", eEnd, 0, 0, "End IME monitoring.");
    defun(env, "nn-ime-shutdown", eShutdown, 0, 0, "Shutdown IME and close pipe.");

    auto feat = env->intern(env, "nn-draw-input-core");
    env->funcall(env, env->intern(env, "provide"), 1, &feat);
  }

  auto sendToEmacs(const char* data, DWORD len) -> void {
    if (pipe_ == INVALID_HANDLE_VALUE) return;
    auto written = DWORD{};
    WriteFile(pipe_, data, len, &written, nullptr);
    WriteFile(pipe_, "\n", 1, &written, nullptr);
  }

  auto begin(emacs_env* env, HWND wid) -> emacs_value {
    if (!wid) return env->intern(env, "nil");

    if (window_ && origWndProc_)
      SetWindowLongPtrW(window_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(origWndProc_));

    window_ = wid;

    if (pipe_ == INVALID_HANDLE_VALUE) {
      pipe_ = CreateNamedPipeW(
        PIPE_NAME,
        PIPE_ACCESS_DUPLEX,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_NOWAIT,
        1,
        PIPE_BUF_SIZE,
        PIPE_BUF_SIZE,
        0,
        nullptr
      );

      if (pipe_ == INVALID_HANDLE_VALUE)
        return env->intern(env, "nil");

      ConnectNamedPipe(pipe_, nullptr);
    }

    origWndProc_ = reinterpret_cast<WNDPROC>(
      SetWindowLongPtrW(window_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(wndProc))
    );

    if (!origWndProc_) {
      window_ = nullptr;
      return env->intern(env, "nil");
    }

    return env->make_integer(env, 1);
  }

  auto end() -> void {
    if (window_ && origWndProc_)
      SetWindowLongPtrW(window_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(origWndProc_));

    window_         = nullptr;
    origWndProc_    = nullptr;
    composition_[0] = '\0';
  }

  auto shutdown() -> void {
    end();
    if (pipe_ != INVALID_HANDLE_VALUE) {
      CloseHandle(pipe_);
      pipe_ = INVALID_HANDLE_VALUE;
    }
  }

  static auto CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wpm, LPARAM lpm) -> LRESULT {
    auto& self = instance(nullptr);

    switch (msg) {
      case WM_IME_STARTCOMPOSITION:
        return 0;

      case WM_IME_COMPOSITION: {
        auto ctx = ImmGetContext(hwnd);
        if (!ctx) break;

        if (lpm & GCS_COMPSTR) {
          auto wbuf      = array<wchar_t, IME_COMP_SIZE>{};
          auto wlen      = ImmGetCompositionStringW(ctx, GCS_COMPSTR, wbuf.data(), sizeof(wbuf));
          auto imeStrLen = 0;
          if (wlen > 0) {
            auto wcount = wlen / sizeof(wchar_t);
            if (wcount > 0 && wbuf[wcount - 1] == L'\0') --wcount;
            imeStrLen = wideToUtf8(
              wbuf.data(),
              wcount,
              self.composition_.data(),
              self.composition_.size()
            );
          } else {
            self.composition_[0] = '\0';
          }
          self.sendToEmacs(self.composition_.data(), static_cast<DWORD>(imeStrLen));
        }

        if (lpm & GCS_RESULTSTR) {
          self.composition_[0] = '\0';
          self.sendToEmacs("", 0);
          ImmReleaseContext(hwnd, ctx);
          return CallWindowProcW(self.origWndProc_, hwnd, msg, wpm, lpm);
        }

        ImmReleaseContext(hwnd, ctx);
        return 0;
      }
      case WM_IME_ENDCOMPOSITION:
        self.composition_[0] = '\0';
        self.sendToEmacs("", 0);
        break;
    }
    return CallWindowProcW(self.origWndProc_, hwnd, msg, wpm, lpm);
  }
};

extern "C" auto emacs_module_init(emacs_runtime* ert) EMACS_NOEXCEPT -> int {
  ImeMonitor::instance(ert->get_environment(ert));
  return 0;
}
