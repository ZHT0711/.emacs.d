;; -*- lexical-binding: t -*-

(setq load-suffixes '(".elc" ".el"))
(setq load-file-rep-suffixes '(""))
(add-hook 'after-init-hook
          (lambda ()
            (setq load-suffixes '(".elc" ".el" ".eln"))
            (setq load-file-rep-suffixes '(".gz" ""))))

(setq jit-lock-defer-time 0
      jit-lock-stealth-time 0.5
      jit-lock-stealth-nice 0.5
      jit-lock-stealth-load 100
      jit-lock-chunk-size 1000
      jit-lock-context-unfontify-pos nil
      font-lock-support-mode 'jit-lock-mode)

(setq bidi-display-reordering nil)
(setq bidi-paragraph-direction 'left-to-right)
(setq fast-but-imprecise-scrolling t)
(setq idle-update-delay 0.5)
(setq process-adaptive-read-buffering nil)
(setq redisplay-skip-fontification-on-input t)
(setq read-process-output-max (* 4 1024 1024))
(setq gc-cons-threshold (* 14 1024 1024))

(add-to-list 'load-path "~/.emacs.d/lisp")
(setq custom-file "~/.emacs.d/lisp/custom.el")
(setq custom-theme-directory "~/.emacs.d/lisp/themes")

(when (eq system-type 'windows-nt)
  (setq w32-quote-process-args t)
  (setenv "LLDB_USE_NATIVE_PDB_READER" "1")
  (let ((msys2-root (getenv "MSYS2")))
    (when msys2-root (dolist (dir '("/usr/bin" "/ucrt64/bin"))
                       (let ((full-path (concat msys2-root dir)))
                         (add-to-list 'exec-path full-path)
                         (setenv "PATH" (concat full-path ";" (getenv "PATH"))))))
    (setq shell-file-name (concat msys2-root "/usr/bin/bash.exe")
          explicit-shell-file-name (concat msys2-root "/usr/bin/bash.exe"))))

(require 'init-package)
(require 'init-font)
(require 'init-base)
(require 'init-advance)
(require 'init-keybind)
(require 'init-lsp)
(require 'init-dap)
(require 'init-lang)
(require 'init-www)
(require 'init-llm)
(require 'init-context-menu)
(require 'init-start)
(load custom-file)
