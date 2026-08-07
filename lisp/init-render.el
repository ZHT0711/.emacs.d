;;; -*- lexical-binding: t -*-
(setq idle-update-delay 0.5
      read-process-output-max (* 4 1024 1024)
      process-adaptive-read-buffering nil)

(use-package jit-lock
  :ensure nil
  :custom
  (jit-lock-defer-time 0)
  (jit-lock-stealth-time 0.5)
  (jit-lock-stealth-nice 0.5)
  (jit-lock-stealth-load 100)
  (jit-lock-chunk-size 1024))

(use-package shr
  :ensure nil
  :hook (shr-mode . visual-line-mode)
  :custom
  (shr-use-fonts t)
  (shr-width 80)
  (shr-indentation 2)
  (shr-bullet "• ")
  (shr-cookie-policy nil)
  (shr-href-highlight t)
  (shr-image-animate t)
  (shr-inhibit-images t)
  (shr-table-corners ?┼)
  (shr-table-horizontal-line ?─)
  (shr-table-vertical-line ?│)
  (shr-color-visible-luminance-min 60)
  (shr-color-visible-distance-min 5))

(use-package nn-markdown-preview
  :ensure nil
  :commands (nn-markdown-preview nn-markdown-preview-mode)
  :init
  (with-eval-after-load 'markdown-mode
    (keymap-set markdown-mode-map "C-c C-p" #'nn-markdown-preview))
  (with-eval-after-load 'markdown-ts-mode
    (keymap-set markdown-ts-mode-map "C-c C-p" #'nn-markdown-preview)))

(use-package nn-fringe-scale
  :ensure nil
  :hook (after-init . nn-fringe-scale-setup))

(provide 'init-render)
