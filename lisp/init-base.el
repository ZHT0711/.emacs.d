;;; -*- lexical-binding: t; -*-

;; UI
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode -1)
(set-fringe-mode '(16 . 16))
(setq ring-bell-function 'ignore
      visible-bell nil
      use-short-answers t
      use-dialog-box nil
      use-file-dialog nil)

;; Editing basics
(global-visual-line-mode t)
(global-display-line-numbers-mode t)
(superword-mode t)
(electric-pair-mode t)
(show-paren-mode t)
(electric-indent-mode t)
(delete-selection-mode t)
(cua-mode t)
(repeat-mode t)
(add-hook 'text-mode-hook #'visual-line-mode)

(setq display-line-numbers-width-start t
      electric-pair-open-newline-between-pairs t
      show-paren-style 'parenthesis
      show-paren-context-when-offscreen nil
      tabify-regexp "^\t* [ \t]+"
      kill-do-not-save-duplicates t
      sentence-end-double-space nil
      require-final-newline t
      comment-auto-fill-only-comments t
      comment-empty-lines t
      comment-padding " "
      truncate-partial-width-windows nil)
(setq-default cursor-type 'box
              tab-width 2
              indent-tabs-mode nil
              tab-always-indent 'complete
              word-wrap t
              truncate-lines t)

;; Encoding
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))
(prefer-coding-system 'utf-8-unix)
(modify-coding-system-alist 'process "*" 'utf-8-unix)
(set-buffer-file-coding-system 'utf-8-unix)
(set-file-name-coding-system 'utf-8-unix)
(set-default-coding-systems 'utf-8-unix)
(set-keyboard-coding-system 'utf-8-unix)
(set-terminal-coding-system 'utf-8-unix)
(set-language-environment "UTF-8")
(setq locale-coding-system 'utf-8-unix)
(setq default-process-coding-system '(utf-8-unix . utf-8-unix))
(unless (eq system-type 'windows-nt)
  (set-clipboard-coding-system 'utf-8)
  (set-selection-coding-system 'utf-8))

;; mode-line
(column-number-mode 1)
(setq eol-mnemonic-unix "LF"
      eol-mnemonic-dos  "CRLF"
      eol-mnemonic-mac  "CR"
      eol-mnemonic-undecided "?"
      mode-line-modes '(:propertize ("" mode-name) help-echo "Major mode")
      coding-system-display
      '((utf-8-unix . "UTF-8")
        (chinese-gbk . "GBK")
        (utf-16-le . "UTF-16LE")
        (utf-16-be . "UTF-16BE")))
(setq-default mode-line-format
              '("%e"
                "   "
                mode-line-modified
                mode-line-buffer-identification
                "   "
                mode-line-position
                "   "
                mode-line-modes
                "   "
                mode-line-mule-info
                "   "
                mode-line-misc-info
                mode-line-end-spaces))

;; TTY
(setq xterm-set-window-title t
      visible-cursor nil)
(when (< emacs-major-version 31)
  (add-hook 'tty-setup-hook #'xterm-mouse-mode))
(when (featurep 'tty-child-frames)
  (add-hook 'tty-setup-hook #'tty-tip-mode))

;; Simple
(use-package simple
  :config
  (dolist (command '(yank yank-pop))
    (advice-add command :after #'indent-region)))

;; Files
(use-package files
  :ensure nil
  :custom
  (create-lockfiles nil)
  (auto-save-default nil)
  (confirm-kill-processes nil)
  (confirm-nonexistent-file-or-buffer nil)
  (backup-directory-alist '(("." . "~/.emacs.d/backups/")))
  (kept-new-versions 5)
  (kept-old-versions 2)
  (delete-old-versions t)
  (version-control t)
  (backup-by-copying t)
  (find-file-visit-truename t)
  (vc-follow-symlinks t)
  (find-file-suppress-same-file-warnings t)
  :config
  (setq auto-save-file-name-transforms
        `(("\\`/[^/]*:\\([^/]*/\\)*\\([^/]*\\)\\'"
           ,(expand-file-name "autosave/tramp-\\2-" user-emacs-directory) sha1)
          ("\\`/\\([^/]+/\\)*\\([^/]+\\)\\'"
           ,(expand-file-name "autosave/\\2-" user-emacs-directory) sha1)))
  (add-to-list 'auto-mode-alist '("/LICENSE\\'" . text-mode)))

;; So-long
(use-package so-long
  :defer t
  :init
  (defvar my-file-lines-threshold-alist
    `(("." . ,(if (fboundp 'igc-info) 25000
                (if (featurep 'native-compile) 20000 15000))))
    "行数阈值 alist，超过时启用 `so-long-minor-mode'。")
  (defun my-so-long-p ()
    "判断当前 buffer 是否过大。"
    (unless (or (minibufferp)
                (string-match-p "\\` " (buffer-name))
                (not buffer-file-name))
      (when (fboundp 'buffer-line-statistics)
        (let ((stats (buffer-line-statistics)))
          (or (> (cadr stats) 5000)
              (when-let* ((maxlines (assoc-default buffer-file-name
                                                   my-file-lines-threshold-alist
                                                   #'string-match-p)))
                (> (car stats) maxlines)))))))
  :custom
  (so-long-threshold 5000)
  :config
  (setq so-long-predicate #'my-so-long-p
        so-long-function #'turn-on-so-long-minor-mode
        so-long-revert-function #'turn-off-so-long-minor-mode)
  (cl-callf2 delq 'font-lock-mode so-long-minor-modes)
  (cl-callf2 delq 'display-line-numbers-mode so-long-minor-modes)
  (add-to-list 'so-long-variable-overrides '(font-lock-maximum-decoration . 1))
  (add-to-list 'so-long-variable-overrides '(save-place-alist . nil))
  (cl-callf append so-long-minor-modes '(eldoc-mode flycheck-mode smartparens-mode undo-tree-mode))
  (global-so-long-mode 1))

;; Savehist
(use-package savehist
  :defer t
  :hook
  (savehist-save . my-savehist-unpropertize-variables-h)
  (savehist-save . my-savehist-remove-unprintable-registers-h)
  :init
  (savehist-mode 1)
  (defun my-savehist-unpropertize-variables-h ()
    "去除 kill-ring 中的 text properties 以减小缓存。"
    (setq kill-ring (mapcar #'substring-no-properties
                            (cl-remove-if-not #'stringp kill-ring))
          register-alist (cl-loop for (reg . item) in register-alist
                                  if (stringp item)
                                  collect (cons reg (substring-no-properties item))
                                  else collect (cons reg item))))
  (defun my-savehist-remove-unprintable-registers-h ()
    "移除不可序列化的寄存器条目。"
    (setq-local register-alist
                (cl-remove-if-not #'savehist-printable register-alist)))
  :custom
  (savehist-file (expand-file-name "savehist" user-emacs-directory))
  (savehist-autosave-interval nil)
  (savehist-save-minibuffer-history t)
  (savehist-additional-variables  '(kill-ring register-alist mark-ring global-mark-ring
                                              search-ring regexp-search-ring)))

;; Subword
(use-package subword
  :hook
  (prog-mode . (lambda ()
                 (unless (derived-mode-p 'lisp-mode 'emacs-lisp-mode 'scheme-mode)
                   (subword-mode 1)))))

;; Goto-address
(use-package goto-addr
  :hook
  (prog-mode . goto-address-mode)
  (text-mode . goto-address-mode))

;; Tramp
(use-package tramp
  :defer t
  :custom
  (remote-file-name-inhibit-cache 60)
  (remote-file-name-inhibit-locks t)
  (remote-file-name-inhibit-auto-save-visited t)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-use-scp-direct-remote-copying t)
  (tramp-completion-reread-directory-timeout 60)
  :config
  (unless (eq system-type 'windows-nt)
    (setq tramp-default-method "ssh"))
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application tramp :protocol "scp")
   'remote-direct-async-process))

;; VC
(use-package vc
  :defer t
  :custom
  (vc-handled-backends '(Git))
  (vc-ignored-dir-regexp
   (format "%s\\|%s" locate-dominating-stop-dir-regexp "[/\\\\]node_modules")))

(use-package vc-annotate
  :defer t
  :bind (:map vc-annotate-mode-map
              ([remap quit-window] . kill-current-buffer)))

(use-package smerge-mode
  :defer t
  :hook (find-file . my-init-smerge-mode-h)
  :config
  (defun my-init-smerge-mode-h ()
    (or (bound-and-true-p so-long-detected-p)
        (bound-and-true-p smerge-mode)
        (save-excursion
          (goto-char (point-min))
          (when (re-search-forward "^<<<<<<< " nil t)
            (smerge-mode 1))))))

;; Whitespace
(use-package whitespace
  :custom
  (whitespace-style '(face tabs spaces tab-mark space-mark))
  (whitespace-display-mappings '((tab-mark 9 [8594 9] [92 9])
                                 (space-mark 32 [183] [46])))
  :hook
  ((prog-mode . whitespace-mode)
   (text-mode . whitespace-mode)
   (before-save . delete-trailing-whitespace)))

;; Pixel scroll
(use-package pixel-scroll
  :custom
  (scroll-margin 0)
  (scroll-step 0)
  (scroll-conservatively 101)
  (scroll-preserve-screen-position t)
  (fast-but-imprecise-scrolling nil)
  (mouse-wheel-progressive-speed nil)
  (mouse-wheel-follow-mouse nil)
  (mouse-wheel-tilt-scroll nil)
  (mouse-wheel-scroll-amount '(2 ((shift) . 2) ((control) . text-scale)))
  :config
  (pixel-scroll-precision-mode 1))

;; Search
(use-package isearch
  :defer t
  :custom
  (search-default-mode 'char-fold-to-regexp)
  (isearch-lazy-highlight t)
  (lazy-highlight-cleanup t))

;; comand
(use-package ls-lisp
  :custom
  (ls-lisp-use-insert-directory-program t))

(use-package grep
  :custom
  (grep-use-headers t)
  (grep-highlight-matches t)
  :config
  (if (executable-find "rg")
      (setq grep-find-command "rg -n --no-heading --smart-case -g '!.git' ")
    (setq grep-find-command "find . -type f -print0 | xargs -0 -r grep -nH \\")))

(use-package compile
  :defer t
  :hook
  (compilation-filter . ansi-color-compilation-filter)
  :custom
  (compile-command "")
  (compilation-scroll-output t)
  (compilation-window-height 20)
  (compilation-skip-threshold 1)
  (compilation-transform-file-name-alist nil)
  (next-error-highlight t)
  (next-error-highlight-no-select t)
  :config
  (when (eq system-type 'windows-nt)
    (define-key compilation-mode-map (kbd "C-c C-k") #'delete-process)))

(provide 'init-base)
