;;; gnus-modern.el --- Modern Gnus interface  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; A personal Gnus interface built from four subsystems:

;; - `gnus-modern-summary'   custom Summary renderer with thread
;;   titles, month separators, folding, and local context commands
;;   (stateless formatting in `gnus-modern-summary-format', navigation
;;   and today-context commands in `gnus-modern-summary-navigate');
;; - `gnus-modern-group'     custom Group renderer with source labels
;;   and decorated Topic rows (formatting in
;;   `gnus-modern-group-format');
;; - `gnus-modern-update'    nonblocking background updates through an
;;   isolated worker process (class in `gnus-modern-update-manager',
;;   worker in `gnus-modern-update-worker', staged application in
;;   `gnus-modern-update-apply').

;; Enable everything with `gnus-modern-mode'; disable with
;; `(gnus-modern-mode -1)'.  Individual subsystems have their own
;; `gnus-modern-...-enable' / `gnus-modern-...-disable' commands.

;;; Code:

(require 'cl-lib)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-renderer)
(require 'gnus-modern-update-manager)
(require 'gnus-modern-update-worker)
(require 'gnus-modern-update-apply)
(require 'gnus-modern-update)
(require 'gnus-modern-group-format)
(require 'gnus-modern-group)
(require 'gnus-modern-summary-format)
(require 'gnus-modern-summary-navigate)
(require 'gnus-modern-summary)

;;;###autoload
(define-minor-mode gnus-modern-mode
  "Toggle the gnus-modern interface for Gnus buffers.

When enabled, installs the custom Group and Summary renderers and
nonblocking background updates.  Individual subsystems can still be
toggled independently with `gnus-modern-update-enable',
`gnus-modern-group-enable', and `gnus-modern-summary-enable' (and
their `-disable' twins)."
  :global t
  :lighter nil
  :group 'gnus-modern
  (if gnus-modern-mode
      (progn
        (gnus-modern-update-enable)
        (gnus-modern-group-enable)
        (gnus-modern-summary-enable))
    (progn
      (gnus-modern-update-disable)
      (gnus-modern-summary-disable)
      (gnus-modern-group-disable))))

(provide 'gnus-modern)
;;; gnus-modern.el ends here
