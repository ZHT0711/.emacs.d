;;; gnus-modern-update-manager.el --- Update manager class  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; The `gnus-modern-update-manager' class and its singleton, defined
;; apart from the methods so that the worker and apply modules can
;; load without a circular dependency.  The singleton
;; `gnus-modern--update-manager' owns every piece of parent-side
;; update state:

;; - live worker `processes' and per-source `progress' / `failures';
;; - `retry-counts' and `retry-timers' for backoff rescheduling;
;; - the staged `apply-queue' with its `apply-timer', progress
;;   counters, `imported-bodies', and `apply-errors';
;; - session timers (`periodic-timer', `start-timer', `header-timer'),
;;   the `next-time' countdown, and the replaced Group `g' binding.

;; Methods over this class live in `gnus-modern-update.el',
;; `gnus-modern-update-apply.el', and `gnus-modern-update-worker.el'.

;;; Code:

(require 'cl-lib)
(require 'eieio)

(defclass gnus-modern-update-manager ()
  ((enabled-p :initform nil
              :documentation "Non-nil when background updates are installed.")
   (processes :initform (make-hash-table :test #'equal)
              :documentation "Live worker processes keyed by server name.")
   (progress :initform (make-hash-table :test #'equal)
             :documentation "Worker progress records keyed by server name.")
   (failures :initform (make-hash-table :test #'equal)
             :documentation "Most recent worker failures keyed by server name.")
   (retry-counts :initform (make-hash-table :test #'equal)
                 :documentation "Consecutive failure counts keyed by server name.")
   (retry-timers :initform (make-hash-table :test #'equal)
                 :documentation "Retry timers keyed by server name.")
   (apply-queue :initform nil
                :documentation "Pending local operations produced by workers.")
   (apply-timer :initform nil
                :documentation "Idle timer applying staged update results.")
   (apply-done :initform 0
               :documentation "Staged operations applied in the current batch.")
   (apply-total :initform 0
                :documentation "Total staged operations in the current batch.")
   (imported-bodies :initform (make-hash-table :test #'equal)
                    :documentation "Imported article numbers keyed by group.")
   (apply-errors :initform (make-hash-table :test #'equal)
                 :documentation "Local staging errors keyed by server name.")
   (periodic-timer :initform nil
                   :documentation "Timer starting the next complete update.")
   (start-timer :initform nil
                :documentation "Idle timer starting the first update.")
   (header-timer :initform nil
                 :documentation "Timer refreshing countdown text.")
   (next-time :initform nil
              :documentation "Absolute time of the next complete update.")
   (source-total :initform 0
                 :documentation "Remote sources in the most recent update.")
   (original-group-g-binding :initform nil
                             :documentation
                             "Binding replaced by `gnus-modern-update'.")
   (group-binding-saved-p :initform nil
                          :documentation
                          "Non-nil after saving the original Group `g' binding."))
  :documentation "Coordinates nonblocking background Gnus updates.")

(defvar gnus-modern--update-manager
  (make-instance 'gnus-modern-update-manager)
  "The singleton background update manager.")

(provide 'gnus-modern-update-manager)
;;; gnus-modern-update-manager.el ends here
