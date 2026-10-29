;;; init-compile.el --- Go/C/C++/Python 的编译与运行模板 -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'init-c-toolchains)

;;; ---------------------------------------------------------------------------
;;; 1. 小工具
;;; ---------------------------------------------------------------------------

(defun my-compile--shq (path)
  "按 POSIX shell 的规则引用 PATH。
`shell-quote-argument' 在 Windows 上给的是 cmd 风格引号，而你的
`shell-file-name' 是 Git bash，所以这里自己来。"
  (if (eq system-type 'windows-nt)
      (concat "'" (replace-regexp-in-string "'" "'\\''" path t t) "'")
    (shell-quote-argument path)))

(defun my-compile--up (marker)
  "从当前文件所在目录向上查找含 MARKER 的目录，返回其绝对路径（结尾带 /）。"
  (when-let* ((file (or (buffer-file-name) default-directory)))
    (locate-dominating-file file marker)))

(defconst my-compile--go-markers '("go.mod" "go.work")
  "Go module 的标记文件。")

(defconst my-compile--cxx-extensions
  '("cc" "cp" "cpp" "cxx" "c++" "C" "hh" "hpp" "hxx" "h++" "cppm" "ixx" "inl" "ipp")
  "按 C++ 处理的扩展名（.C 大写是 C++ 的老习惯）。")

(defconst my-compile--c-flags "-Wall -Wextra -g -O0"
  "传给 gcc/g++ 的通用开关；想要优化改成 -O2 即可。")

(defconst my-compile--c-std   "c17")
(defconst my-compile--cxx-std "c++20")

(defun my-compile-cxx-p ()
  "当前缓冲区是否按 C++ 处理。"
  (or (derived-mode-p 'c++-mode 'c++-ts-mode)
      (let ((ext (file-name-extension (or (buffer-file-name) ""))))
        (and ext (member ext my-compile--cxx-extensions)))))

(defun my-compile-lang ()
  "当前缓冲区的语言：`go' / `c' / `cxx' / `python'；判断不出返回 nil。"
  (cond
   ((derived-mode-p 'go-mode 'go-ts-mode) 'go)
   ((derived-mode-p 'python-mode 'python-ts-mode) 'python)
   ((derived-mode-p 'c-mode 'c-ts-mode 'c++-mode 'c++-ts-mode 'simpc-mode)
    (if (my-compile-cxx-p) 'cxx 'c))))

;;; ---------------------------------------------------------------------------
;;; 2. Go
;;; ---------------------------------------------------------------------------

(defun my-compile-go-root ()
  "go.mod / go.work 所在目录；没有（单文件脚本）则返回 nil。"
  (cl-some #'my-compile--up my-compile--go-markers))

(defun my-compile-go-command ()
  "Go 的编译检查命令：module 内用 `go build ./...'，否则 `go build <file>'。"
  (if-let* ((root (my-compile-go-root)))
      (format "cd %s && go build ./..." (my-compile--shq (directory-file-name root)))
    (format "go build %s" (my-compile--shq (buffer-file-name)))))

(defun my-compile-go-run-command ()
  "Go 的运行命令：module 内用 `go run .'，否则 `go run <file>'。"
  (if-let* ((root (my-compile-go-root)))
      (format "cd %s && go run ." (my-compile--shq (directory-file-name root)))
    (format "go run %s" (my-compile--shq (buffer-file-name)))))

(defun my-compile-go-test-command ()
  "Go 的测试命令。"
  (if-let* ((root (my-compile-go-root)))
      (format "cd %s && go test ./..." (my-compile--shq (directory-file-name root)))
    (format "go vet %s" (my-compile--shq (buffer-file-name)))))

;;; ---------------------------------------------------------------------------
;;; 3. C / C++（simpc-mode 也在内）
;;; ---------------------------------------------------------------------------

(defconst my-compile-c-build-dirs
  '("build" "cmake-build-debug" "cmake-build-release" "out/build")
  "CMake 构建目录候选。")

(defun my-compile-c-cmake-root ()
  (my-compile--up "CMakeLists.txt"))

(defun my-compile-c-make-root ()
  (or (my-compile--up "Makefile") (my-compile--up "makefile")))

(defun my-compile-c-cmake-build-dir ()
  "已经存在的 CMake 构建目录（绝对路径），没有则 nil。"
  (when-let* ((root (my-compile-c-cmake-root)))
    (when-let* ((dir (cl-find-if (lambda (d) (file-directory-p (expand-file-name d root)))
                                 my-compile-c-build-dirs)))
      (expand-file-name dir root))))

(defun my-compile-c-single-exe ()
  "单文件编译时的输出可执行文件路径。"
  (concat (file-name-sans-extension (buffer-file-name))
          (if (eq system-type 'windows-nt) ".exe" "")))

(defun my-compile-c-single-command ()
  "没有构建系统时，用当前选定的 GCC/Clang 编译当前文件。
只传相对路径：compile 就在文件所在目录里跑，纯 ASCII 的命令行
可以躲开 Windows 上 Emacs/bash/gcc 之间转码不一致的坑。"
  (let* ((cxx (my-compile-cxx-p))
         (exe (file-name-nondirectory (my-compile-c-single-exe)))
         (src (file-name-nondirectory (buffer-file-name))))
    (format "%s -std=%s %s -o %s %s%s"
            (my-c-toolchain-compiler cxx)
            (if cxx my-compile--cxx-std my-compile--c-std)
            my-compile--c-flags
            (my-compile--shq exe)
            (my-compile--shq src)
            (if cxx "" " -lm"))))

(defun my-compile-c-exe (dir base)
  "在 DIR 下找名为 BASE 的可执行文件（自动尝试 .exe）。"
  (or (cl-find-if #'file-exists-p
                  (mapcar (lambda (suffix) (expand-file-name (concat base suffix) dir))
                          '(".exe" "")))
      (expand-file-name (concat base (if (eq system-type 'windows-nt) ".exe" "")) dir)))

(defun my-compile-c-command ()
  "C/C++ 的编译命令：CMake > Makefile > 单文件。"
  (cond
   ((my-compile-c-cmake-build-dir)
    (format "cmake --build %s -j" (my-compile--shq (my-compile-c-cmake-build-dir))))
   ((my-compile-c-make-root)
    (format "make -C %s" (my-compile--shq (directory-file-name (my-compile-c-make-root)))))
   (t (my-compile-c-single-command))))

(defun my-compile-c-run-command ()
  "C/C++ 的「编译并运行」命令。"
  (let ((build (my-compile-c-cmake-build-dir))
        (base  (file-name-base (buffer-file-name))))
    (cond
     (build (format "%s && %s" (my-compile-c-command)
                    (my-compile--shq (my-compile-c-exe build base))))
     ((my-compile-c-make-root)
      (format "%s && %s" (my-compile-c-command)
              (my-compile--shq (my-compile-c-exe
                                (directory-file-name (my-compile-c-make-root)) base))))
     (t (format "%s && %s" (my-compile-c-single-command)
                (my-compile--shq
                 (concat "./" (file-name-nondirectory (my-compile-c-single-exe)))))))))

;;; ---------------------------------------------------------------------------
;;; 4. Python
;;; ---------------------------------------------------------------------------

(defun my-compile-python-bin ()
  "优先用项目 venv 里的 python，其次 $VIRTUAL_ENV，最后 PATH 上的 python。"
  (or (cl-find-if #'file-exists-p
                  (delq nil
                        (list (when-let* ((root (my-compile--up ".venv")))
                                (expand-file-name "Scripts/python.exe" root))
                              (when-let* ((root (my-compile--up ".venv")))
                                (expand-file-name "bin/python" root))
                              (when-let* ((env (getenv "VIRTUAL_ENV")))
                                (expand-file-name "Scripts/python.exe" env))
                              (when-let* ((env (getenv "VIRTUAL_ENV")))
                                (expand-file-name "bin/python" env)))))
      "python"))

(defun my-compile-python-command ()
  "Python 的语法检查命令（只编译不执行，快）。"
  (format "%s -m py_compile %s"
          (my-compile--shq (my-compile-python-bin))
          (my-compile--shq (buffer-file-name))))

(defun my-compile-python-run-command ()
  "Python 的运行命令。"
  (format "%s %s"
          (my-compile--shq (my-compile-python-bin))
          (my-compile--shq (buffer-file-name))))

(defun my-compile-python-test-command ()
  "Python 的测试命令。"
  (format "%s -m pytest" (my-compile--shq (my-compile-python-bin))))

;;; ---------------------------------------------------------------------------
;;; 5. 按语言分发
;;; ---------------------------------------------------------------------------

;;;###autoload
(defun my-compile-command ()
  "按当前缓冲区的语言返回编译/检查命令。"
  (pcase (my-compile-lang)
    ('go     (my-compile-go-command))
    ('c      (my-compile-c-command))
    ('cxx    (my-compile-c-command))
    ('python (my-compile-python-command))))

;;;###autoload
(defun my-compile-run-command ()
  "按当前缓冲区的语言返回「编译并运行」命令。"
  (pcase (my-compile-lang)
    ('go     (my-compile-go-run-command))
    ('c      (my-compile-c-run-command))
    ('cxx    (my-compile-c-run-command))
    ('python (my-compile-python-run-command))))

;;;###autoload
(defun my-compile-test-command ()
  "按当前缓冲区的语言返回测试命令。"
  (pcase (my-compile-lang)
    ('go     (my-compile-go-test-command))
    ('python (my-compile-python-test-command))
    ('c      (my-compile-c-command))
    ('cxx    (my-compile-c-command))))

;;;###autoload
(defun my-compile (&optional arg)
  "编译当前缓冲区，命令由 `my-compile-command' 按语言给出。
带前缀参数 ARG 时改调 `compile' 的交互版本，可以自己改命令。"
  (interactive "P")
  (if arg
      (call-interactively #'compile)
    (compile (or (my-compile-command) compile-command))))

;;;###autoload
(defun my-compile-run (&optional arg)
  "编译并运行当前缓冲区。ARG 同 `my-compile'。"
  (interactive "P")
  (if arg
      (call-interactively #'compile)
    (compile (or (my-compile-run-command) compile-command))))

;;;###autoload
(defun my-compile-test (&optional arg)
  "跑当前缓冲区的测试。ARG 同 `my-compile'。"
  (interactive "P")
  (if arg
      (call-interactively #'compile)
    (compile (or (my-compile-test-command) compile-command))))

;;;###autoload
(defun my-compile-kill ()
  "停掉 *compilation* 里正在跑的进程。"
  (interactive)
  (let ((buf (get-buffer "*compilation*")))
    (if (and buf (get-buffer-process buf))
        (with-current-buffer buf (delete-process (get-buffer-process buf)))
      (message "没有正在运行的编译进程"))))

;; 打开文件时就把 `compile-command' 设好，这样你原有的 C-c c 也能直接跑。
(defun my-compile-set-command-h ()
  "把 `compile-command' 设成本语言的默认命令。"
  (when-let* ((cmd (ignore-errors (my-compile-command))))
    (setq-local compile-command cmd)))

(dolist (hook '(go-ts-mode-hook go-mode-hook
                c-mode-hook c-ts-mode-hook c++-mode-hook c++-ts-mode-hook
                simpc-mode-hook
                python-mode-hook python-ts-mode-hook))
  (add-hook hook #'my-compile-set-command-h))

(keymap-global-set "C-c b b" #'my-compile)
(keymap-global-set "C-c b r" #'my-compile-run)
(keymap-global-set "C-c b t" #'my-compile-test)
(keymap-global-set "C-c b k" #'my-compile-kill)
(keymap-global-set "C-c b s" #'my-c-select-toolchain)

;;; ---------------------------------------------------------------------------
;;; 6. quickrun：一键跑当前文件
;;; ---------------------------------------------------------------------------

(use-package quickrun
  :ensure t
  :custom
  (quickrun-focus-p nil)
  (quickrun-truncate-lines t)
  :bind (("C-c b q" . quickrun)
         ("C-c b Q" . quickrun-with-arg)
         ("C-c b c" . quickrun-compile-only))
  :config
  ;; .go 在你的 Emacs 里是 go-ts-mode，而 quickrun 只内置了 go-mode 的映射，
  ;; 所以补一个；顺带把它那个用 Unix /dev/null 的 compile-only 换成 go vet。
  (quickrun-add-command
   "go/go-run"
   '((:command . "go")
     (:exec . ("%c run %s %a"))
     (:compile-only . "%c vet %s")
     (:tempfile . nil)
     (:description . "go run <file>"))
   :default "go" :mode 'go-ts-mode)

  ;; .cpp/.cc 走扩展名映射到 "c++"，:default 会把内置模板整体换掉；
  ;; :mode simpc-mode 是给 .h/.hpp 这类没有扩展名映射的文件兜底。
  (quickrun-add-command
   "c++/g++-c++20"
   '((:command . "g++")
     (:exec . ("%c -x c++ -std=c++20 -Wall -Wextra -g -O0 %o -o %e %s" "%e %a"))
     (:compile-only . "%c -x c++ -std=c++20 -Wall -Wextra -fsyntax-only %s")
     (:remove . ("%e"))
     (:description . "Compile & run C++20 with g++"))
   :default "c++" :mode 'simpc-mode)

  (quickrun-add-command
   "c/gcc-c17"
   '((:command . "gcc")
     (:exec . ("%c -x c -std=c17 -Wall -Wextra -g -O0 %o -o %e %s" "%e %a"))
     (:compile-only . "%c -x c -std=c17 -Wall -Wextra -fsyntax-only %s")
     (:remove . ("%e"))
     (:description . "Compile & run C17 with gcc"))
   :default "c")

  ;; Optional Clang commands; GCC remains Quickrun's default until selected.
  (quickrun-add-command
   "c++/clang++-c++20"
   '((:command . "clang++")
     (:exec . ("%c -x c++ -std=c++20 -Wall -Wextra -g -O0 %o -o %e %s" "%e %a"))
     (:compile-only . "%c -x c++ -std=c++20 -Wall -Wextra -fsyntax-only %s")
     (:remove . ("%e"))
     (:description . "Compile & run C++20 with clang++")))
  (quickrun-add-command
   "c/clang-c17"
   '((:command . "clang")
     (:exec . ("%c -x c -std=c17 -Wall -Wextra -g -O0 %o -o %e %s" "%e %a"))
     (:compile-only . "%c -x c -std=c17 -Wall -Wextra -fsyntax-only %s")
     (:remove . ("%e"))
     (:description . "Compile & run C17 with clang")))

  (quickrun-add-command
   "python/python-run"
   '((:command . "python")
     (:exec . ("%c %s %a"))
     (:compile-only . "%c %s")
     (:description . "Run Python script"))
   :default "python"))

(provide 'init-compile)

;;; ---------------------------------------------------------------------------
;;; 7. 需要 stdin 的程序：在真终端里跑（ghostel）
;;; ---------------------------------------------------------------------------
;; `compile' 把命令接在管道上，程序检测不到 tty；而 compile buffer 是只读的，
;; 所以 Python 的 input()、C++ 的 cin 会直接卡死。ghostel 能在 Emacs 里开真
;; pty：既保留 compilation 的跳错误能力，又能随时把键盘交给程序。
;;
;;   C-c b i              交互式运行（起手就能敲键盘）
;;   C-c b r 中途要输入   在输出 buffer 里按 C-c C-j 切成交互输入
;;   C-c C-e / C-c C-t    切回只读导航
;;
;; 这里不启用 `ghostel-compile-global-mode'，你原有的 C-c c / M-x compile
;; 行为完全不变。

;;;###autoload
(defun my-run-pty (cmd &optional interactive)
  "在 ghostel 的真 pty 里跑 CMD（保留 n/p 跳错误、g 重跑）。
INTERACTIVE 非 nil 时一开始就把键盘交给进程，适合要读 stdin 的程序。
ghostel 用不了时退回普通 `compile'。"
  (if (ignore-errors (require 'ghostel-compile) t)
      ;; let 住 compile-command：ghostel-compile 会把它 setq 成全局值
      (let ((compile-command cmd))
        (ghostel-compile cmd interactive))
    (compile cmd)))

;;;###autoload
(defun my-run-python-repl ()
  "在 *Python* REPL 里跑当前文件：状态留着，之后能接着敲。
用项目 venv 里的解释器（若有），-u 保证输出不被缓冲。"
  (interactive)
  (require 'python)
  (let ((src (current-buffer))
        (default-directory (or (and (buffer-file-name)
                                    (file-name-directory (buffer-file-name)))
                               default-directory))
        (python-shell-interpreter (my-compile-python-bin))
        (python-shell-interpreter-args "-u -i"))
    (run-python nil nil t)                ;; cmd noshow new
    (with-current-buffer src
      (python-shell-send-buffer))))

;;;###autoload
(defun my-run-interactive (&optional arg)
  "交互式运行当前文件（stdin 可用）。
Python 默认进 *Python* REPL；其它语言在 ghostel 真终端里跑。
带前缀参数 ARG 时一律走 ghostel 终端，Python 也当脚本跑一遍。"
  (interactive "P")
  (let ((cmd (or (my-compile-run-command) compile-command)))
    (if (and (eq (my-compile-lang) 'python) (not arg))
        (my-run-python-repl)
      (my-run-pty cmd t))))

(keymap-global-set "C-c b i" #'my-run-interactive)

;;; init-compile.el ends here
