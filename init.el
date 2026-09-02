;;; -*- lexical-binding: t -*-
(set-default-coding-systems 'utf-8-unix)
(set-locale-environment "en_US.UTF-8")
(set-charset-priority 'unicode)
(if (eq system-type 'windows-nt)
    (progn
      (set-clipboard-coding-system 'utf-16-le)
      (setq default-process-coding-system `(utf-8-dos . ,locale-coding-system)
            process-coding-system-alist
            '(("[pP][lL][iI][nN][kK]" utf-8-dos . gbk-dos)
              ("[cC][mM][dD][pP][rR][oO][xX][yY]" utf-8-dos . gbk-dos))))
  (set-clipboard-coding-system 'utf-8-unix)
  (setq default-process-coding-system '(utf-8-unix . utf-8-unix)))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(let ((file-name-handler-alist nil))
  (require 'nn-world-theme)
  (require 'init-def)
  (load custom-file)
  (when (display-graphic-p)
    (require 'init-font))
  (require 'init-base)
  (require 'init-advanced)
  (require 'init-display)
  (require 'init-editor)
  (require 'init-lang)
  (require 'init-debug)
  (require 'init-diagnostics)
  (require 'init-completion)
  (require 'init-navigation)
  (require 'init-imenu)
  (require 'init-vc)
  (require 'init-www)
  (require 'init-utils)
  (require 'init-mode-line)
  (require 'init-terminal)
  (require 'init-keybind)
  (require 'init-word-move)
  (require 'init-context-menu)
  ;; Local init-home shows Recent Files; upstream enables recentf inside its own init-home.
  (recentf-mode 1)
  (require 'init-home))

;; === nn-world current-line number face override (local preference) ===
(defun my-nn-world-line-number-face ()
  "Pink background with deep-red text for the current line number."
  (when (member 'nn-world custom-enabled-themes)
    (set-face-attribute 'line-number-current-line nil
                        :foreground "#5a1d1d" :background "#f0b0e0")))
(add-hook 'after-load-theme-hook #'my-nn-world-line-number-face)
(my-nn-world-line-number-face)
;; === end nn-world line-number face override ===
