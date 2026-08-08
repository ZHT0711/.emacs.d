;;; gnus-modern-core.el --- Shared utilities for gnus-modern  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Small self-contained helpers shared by the gnus-modern modules.
;; They replace the private bs-lib package, so
;; the package has no external dependencies.

;;; Code:

(require 'cl-lib)
(require 'seq)

;;; Text helpers

(defun gnus-modern--truncate-string (string width)
  "Return STRING truncated to WIDTH columns with an ellipsis.
Return STRING unchanged when it already fits."
  (if (<= (string-width string) width)
      string
    (truncate-string-to-width string (max 0 width) nil nil "…")))

(defun gnus-modern--right-padding (string &optional width)
  "Return SPACES right-aligning STRING within WIDTH columns.
WIDTH defaults to the selected window's body width.  Return the
empty string when STRING is already at least WIDTH columns wide."
  (let ((width (or width (window-body-width) 100)))
    (make-string (max 0 (- width (string-width string))) ?\s)))

(defun gnus-modern--top-spacing-prefix (height)
  "Return a line prefix adding HEIGHT lines of spacing above a line."
  (propertize " " 'line-height height))

(defun gnus-modern--sanitize-single-line (string)
  "Return STRING with line breaks replaced by spaces."
  (replace-regexp-in-string "[\n\r]+" " " (or string "")))

(defun gnus-modern--decode-raw-utf-8 (string)
  "Re-decode STRING that was decoded with the wrong coding system."
  (condition-case nil
      (decode-coding-string
       (encode-coding-string string 'raw-text) 'utf-8)
    (error string)))

;;; Time and collection helpers

(defun gnus-modern--today-time-bounds ()
  "Return (START . END) epoch seconds bounding the local calendar day."
  (let* ((now (decode-time))
         (start (float-time
                 (encode-time 0 0 0 (nth 3 now) (nth 4 now)
                              (nth 5 now)))))
    (cons start (+ start 86400))))

(defun gnus-modern--group-by (list function)
  "Group LIST items by FUNCTION keys, preserving first-seen order."
  (let ((table (make-hash-table :test #'equal))
        order)
    (dolist (item list)
      (let ((key (funcall function item)))
        (unless (gethash key table)
          (push key order))
        (push item (gethash key table))))
    (mapcar (lambda (key) (nreverse (gethash key table)))
            (nreverse order))))

(defun gnus-modern--message-base-subject (subject)
  "Return SUBJECT without reply/forward prefixes and brackets.
Reply/forward prefixes (Re:, Fwd:, Aw:, SV:, 答复:, 回复:) and
leading bracket groups such as `[PATCH]' are stripped repeatedly,
with the result trimmed of surrounding whitespace."
  (let ((subject (or subject "")))
    (while (string-match
            (concat "\\`\\(?:\\[[^]]*\\]\\s-*\\)*"
                    "\\(?:re\\|fwd\\|fw\\|aw\\|sv\\|答复\\|回复\\)"
                    "[:：]\\s-*")
            subject)
      (setq subject (replace-match "" nil t subject)))
    (string-trim subject)))

;;; Gnus buffer helpers

(defun gnus-modern--group-buffers ()
  "Return live Gnus Group buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-group-mode)))
   (buffer-list)))

(defun gnus-modern--summary-buffers ()
  "Return live Gnus Summary buffers."
  (cl-remove-if-not
   (lambda (buffer)
     (with-current-buffer buffer
       (derived-mode-p 'gnus-summary-mode)))
   (buffer-list)))

(provide 'gnus-modern-core)
;;; gnus-modern-core.el ends here
