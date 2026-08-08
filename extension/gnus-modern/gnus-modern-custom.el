;;; gnus-modern-custom.el --- Faces and options for gnus-modern  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Faces and user options shared by the gnus-modern modules.

;;; Code:

(defgroup gnus-modern nil
  "Personal Gnus extensions."
  :group 'gnus)

(defface gnus-modern-summary-title-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for thread subjects."
  :group 'gnus-modern)

(defface gnus-modern-summary-correspondent-face
  '((t :inherit gnus-summary-normal-read :slant italic))
  "Face for article correspondents in Summary buffers."
  :group 'gnus-modern)

(defface gnus-modern-summary-unread-correspondent-face
  '((t :inherit default :weight bold :slant italic))
  "Face for correspondents of unread articles."
  :group 'gnus-modern)

(defface gnus-modern-summary-unread-mark-face
  '((t :inherit error :weight bold))
  "Face for unread article marks in Summary buffers."
  :group 'gnus-modern)

(defface gnus-modern-summary-attention-mark-face
  '((t :inherit warning :weight bold))
  "Face for article marks requiring attention."
  :group 'gnus-modern)

(defface gnus-modern-summary-activity-mark-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for reply, forwarding, and new-article marks."
  :group 'gnus-modern)

(defface gnus-modern-summary-stored-mark-face
  '((t :inherit success :weight bold))
  "Face for locally stored article marks."
  :group 'gnus-modern)

(defface gnus-modern-summary-quiet-mark-face
  '((t :inherit shadow))
  "Face for inactive and unavailable article marks."
  :group 'gnus-modern)

(defface gnus-modern-summary-negative-mark-face
  '((t :inherit error :weight bold))
  "Face for rejected, failed, and low-score article marks."
  :group 'gnus-modern)

(defface gnus-modern-summary-label-face
  '((t :inherit gnus-summary-normal-read :weight regular :underline nil))
  "Parent face for labels in Summary buffers."
  :group 'gnus-modern)

(defface gnus-modern-summary-thread-count-face
  '((t :inherit (font-lock-keyword-face gnus-modern-summary-label-face)
       :weight semibold :inverse-video t))
  "Face for thread article-count labels."
  :group 'gnus-modern)

(defface gnus-modern-summary-unread-thread-count-face
  '((t :inherit (error gnus-modern-summary-label-face)
       :weight semibold :inverse-video t))
  "Face for thread counts containing unread articles."
  :group 'gnus-modern)

(defface gnus-modern-summary-timestamp-face
  '((t :inherit (shadow gnus-modern-summary-label-face)
       :weight normal :slant normal :strike-through nil))
  "Face for article timestamps."
  :group 'gnus-modern)

(defface gnus-modern-summary-context-face
  '((t :inherit shadow :weight normal))
  "Face for old articles displayed only to connect a thread."
  :group 'gnus-modern)

(defface gnus-modern-summary-month-face
  '((t :inherit font-lock-keyword-face
       :height 1.10 :underline nil :extend t))
  "Face used for month separators in Summary buffers."
  :group 'gnus-modern)

(defface gnus-modern-header-face
  '((t :inherit header-line :height 1.0))
  "Base face used for complete Gnus header lines."
  :group 'gnus-modern)

(defface gnus-modern-header-label-face
  '((t :inherit header-line :weight bold))
  "Face used for labels in Gnus header lines."
  :group 'gnus-modern)

(defface gnus-modern-update-value-face
  '((t :inherit font-lock-keyword-face :slant italic))
  "Face used for update times and progress values."
  :group 'gnus-modern)

(defface gnus-modern-summary-group-face
  '((t :inherit header-line :weight bold))
  "Face for sources in a Summary header line."
  :group 'gnus-modern)

(defface gnus-modern-summary-group-name-face
  '((t :inherit font-lock-keyword-face
       :weight bold :slant italic))
  "Face for the group name in a Summary header line."
  :group 'gnus-modern)

(defface gnus-modern-summary-group-unread-face
  '((t :inherit error :weight semibold))
  "Face for nonzero unread counts on Summary overview lines."
  :group 'gnus-modern)

(defface gnus-modern-summary-group-empty-unread-face
  '((t :inherit shadow))
  "Face for zero unread counts on Summary overview lines."
  :group 'gnus-modern)

(defface gnus-modern-summary-group-loaded-face
  '((t :inherit success))
  "Face for loaded article counts on Summary overview lines."
  :group 'gnus-modern)

(defface gnus-modern-summary-fold-indicator-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for folded-reply indicators."
  :group 'gnus-modern)

(defface gnus-modern-group-unread-face
  '((t :inherit error :weight bold))
  "Face for nonzero unread counts in Group buffers."
  :group 'gnus-modern)

(defface gnus-modern-group-read-face
  '((t :inherit shadow))
  "Face for zero unread counts in Group buffers."
  :group 'gnus-modern)

(defface gnus-modern-group-total-face
  '((t :inherit shadow))
  "Face for total article counts in Group buffers."
  :group 'gnus-modern)

(defface gnus-modern-group-separator-face
  '((t :inherit shadow))
  "Face for separators in Group buffer article counts."
  :group 'gnus-modern)

(defface gnus-modern-group-name-face
  '((t :inherit default))
  "Face for group names regardless of their unread state."
  :group 'gnus-modern)

(defface gnus-modern-group-source-face
  '((t :inherit shadow))
  "Face for right-aligned source labels in Group buffers."
  :group 'gnus-modern)

(defface gnus-modern-group-topic-face
  '((t :inherit gnus-modern-summary-title-face))
  "Face for topic names in Group buffers."
  :group 'gnus-modern)

(defface gnus-modern-group-root-topic-face
  '((t :height 1.30))
  "Relative size applied to the root Topic row."
  :group 'gnus-modern)

(defface gnus-modern-group-top-level-topic-face
  '((t :height 1.15))
  "Relative size applied to top-level Topic rows."
  :group 'gnus-modern)

(defface gnus-modern-group-topic-count-face
  '((t :inherit error :weight semibold :inverse-video nil))
  "Face for nonzero topic unread counts."
  :group 'gnus-modern)

(defface gnus-modern-group-topic-empty-count-face
  '((t :inherit shadow))
  "Face for zero topic unread counts."
  :group 'gnus-modern)

(defcustom gnus-modern-summary-date-format "%m/%d/%Y %I:%M:%S %p"
  "Format used for article dates in Summary buffers."
  :type 'string
  :group 'gnus-modern)

(defcustom gnus-modern-summary-month-format "%Y %b"
  "Format used for root-article month separators in Summary buffers."
  :type 'string
  :group 'gnus-modern)

(defcustom gnus-modern-summary-month-line-spacing 0.65
  "Relative spacing added above and below Summary month separators."
  :type 'number
  :group 'gnus-modern)

(defcustom gnus-modern-summary-fold-indicator ?▸
  "Character displayed at the left edge of an article with folded replies."
  :type 'character
  :group 'gnus-modern)

(defcustom gnus-modern-summary-thread-count-digits 4
  "Minimum columns reserved for complete thread article-count labels.
The width includes separators and a trailing context marker."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-summary-thread-count-padding 0.5
  "Colored padding beside thread article counts, in character widths."
  :type 'number
  :group 'gnus-modern)

(defcustom gnus-modern-summary-fallback-width 100
  "Width used when a Summary buffer has no live window."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-summary-auto-extend-count 100
  "Number of older articles inserted when Summary movement reaches its end.
A value of zero disables batch insertion without changing
`gnus-auto-extend-newsgroup'."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-summary-follow-visible-article nil
  "Whether Summary navigation follows point in a visible Article buffer."
  :type 'boolean
  :group 'gnus-modern)

(defcustom gnus-modern-context-buffer-name "*Gnus Thread Context*"
  "Name of the buffer containing the latest Gnus context."
  :type 'string
  :group 'gnus-modern)

(defcustom gnus-modern-today-context-maximum-length 900000
  "Maximum number of characters in a Gnus today context.
Article bodies share the available space equally after reserving
space for context, thread, and article metadata.  This keeps the
result below provider limits while retaining every article."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-summary-display-thread-context nil
  "Whether to display the generated thread context buffer.
When nil, keep the buffer named by `gnus-modern-context-buffer-name'
hidden and select the current Summary row.  When non-nil, display
that buffer and select all of its text."
  :type 'boolean
  :group 'gnus-modern)

(defcustom gnus-modern-summary-thread-context-hook nil
  "Hook run after preparing a Gnus context.
The hook runs in the originating Summary or Group buffer while the
buffer named by `gnus-modern-context-buffer-name' contains the selected
subthread or today's articles."
  :type 'hook
  :group 'gnus-modern)

(defcustom gnus-modern-group-count-width 9
  "Minimum total columns reserved for a Group buffer article count."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-group-source-names nil
  "Alist mapping NNTP server addresses to Group buffer source labels.
Each element has the form (ADDRESS . NAME).  NNTP servers absent
from the alist use the label `Usenet'."
  :type '(alist :key-type string :value-type string)
  :group 'gnus-modern)

(defcustom gnus-modern-group-fallback-width 100
  "Width used when a Group buffer has no live window."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-group-topic-spacing-height 0.65
  "Relative spacing added around Topic rows."
  :type 'number
  :group 'gnus-modern)

(defcustom gnus-modern-header-bottom-spacing 0.5
  "Relative line height reserved below Gnus header lines."
  :type 'number
  :group 'gnus-modern)

(defcustom gnus-modern-update-interval (* 30 60)
  "Seconds between complete background Gnus updates."
  :type 'natnum
  :group 'gnus-modern)

(defcustom gnus-modern-update-download-bodies t
  "Whether background updates download unread article bodies.
When nil, updates still retrieve overview data needed for group state.
Article bodies remain available on demand through
the configured Gnus method."
  :type 'boolean
  :group 'gnus-modern)

(defcustom gnus-modern-update-retry-delays '(300 900 1800)
  "Seconds to wait after consecutive background update failures.
After exhausting the list, continue using its final delay."
  :type '(repeat natnum)
  :group 'gnus-modern)

(defcustom gnus-modern-update-stall-timeout 120
  "Seconds without worker output before an update is considered stalled."
  :type 'natnum
  :group 'gnus-modern)

(provide 'gnus-modern-custom)
;;; gnus-modern-custom.el ends here
