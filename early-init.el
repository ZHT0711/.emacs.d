;;; -*- lexical-binding: t -*-
(setq gc-cons-percentage 1.0)
(if noninteractive
    (setq gc-cons-threshold 134217728)  ; 128MB
  (setq gc-cons-threshold most-positive-fixnum))

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 16 1024 1024)  ; 16MB
                  gc-cons-percentage 0.1)))

(setq default-frame-alist
      '((menu-bar-lines . 0)
        (tool-bar-lines . 0)
        (horizontal-scroll-bars)
        (vertical-scroll-bars)
        (fullscreen . maximized)))
(setq menu-bar-mode -1
      tool-bar-mode -1
      scroll-bar-mode -1
      use-short-answers t
      use-dialog-box nil
      use-file-dialog nil)
(unless noninteractive
  (setq frame-inhibit-implied-resize t
        inhibit-startup-screen t
        inhibit-startup-echo-area-message user-login-name
        initial-scratch-message nil
        initial-major-mode 'fundamental-mode))

(setq-default inhibit-redisplay t
              inhibit-message t)
(add-hook 'window-setup-hook
          (lambda ()
            (setq-default inhibit-redisplay nil
                          inhibit-message nil)
            (redraw-frame)))

(setq file-name-handler-alist nil
      read-process-output-max (* 64 1024)
      native-comp-jit-compilation t
      auto-mode-case-fold nil
      package-enable-at-startup nil
      load-suffixes `(".elc" ".el")
      load-prefer-newer noninteractive)

(put 'if-let 'byte-obsolete-info nil)
(put 'when-let 'byte-obsolete-info nil)
(setq-default custom-file "~/.emacs.d/custom.el")
(push "~/.emacs.d/lisp/" load-path)
(push "~/.emacs.d/lisp/lang" load-path)
(dolist (sub (directory-files (expand-file-name "extension" user-emacs-directory) t "\\`[^.]"))
  (when (file-directory-p sub)
    (push sub load-path)))

(when (boundp 'w32-get-true-file-attributes)
  (setq w32-get-true-file-attributes nil
        w32-pipe-read-delay 0
        w32-pipe-buffer-size (* 64 1024)))
