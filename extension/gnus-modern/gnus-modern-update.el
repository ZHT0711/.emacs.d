;;; gnus-modern-update.el --- Nonblocking background Gnus updates  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Fetches subscribed NNTP groups in an isolated Emacs subprocess and
;; applies the results to the live Agent, Summary buffers, and Group
;; buffer without blocking the main Emacs process.

;; This file owns the manager-side lifecycle: progress and header
;; status, source gathering and retries, session enablement, and the
;; public commands.  The manager class lives in
;; `gnus-modern-update-manager.el', the worker subprocess in
;; `gnus-modern-update-worker.el', and process plumbing plus staged
;; application in `gnus-modern-update-apply.el'.

;; Enable with `gnus-modern-update-enable'; run one update with
;; `gnus-modern-update'.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'eieio)
(require 'gnus)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-update-manager)
(require 'gnus-modern-update-worker)
(require 'gnus-modern-update-apply)

(declare-function gnus-modern--start-source
                  "gnus-modern-update-apply" (manager entry))
(declare-function gnus-modern--stop
                  "gnus-modern-update-apply" (manager))
(declare-function gnus-list-of-unread-articles "gnus-sum" (group))
(declare-function gnus-agent-load-alist "gnus-agent" (group))
(declare-function gnus-agent-article-name "gnus-agent" (article group))
(declare-function auth-source-search "auth-source" (&rest spec))
(declare-function gnus-summary-goto-subject
                  "gnus-sum" (article &optional force silent))
(declare-function gnus-summary-article-number "gnus-sum" ())

(defvar gnus-group-mode-map)
(defvar gnus-level-subscribed)
(defvar gnus-newsrc-alist)

(defvar gnus-modern--update-header-map
  (let ((map (make-sparse-keymap)))
    (define-key map [header-line mouse-1] #'gnus-modern-update)
    (define-key map [mode-line mouse-1] #'gnus-modern-update)
    map)
  "Keymap used by the clickable Group update status.")

;;; Activity and progress

(cl-defmethod gnus-modern--active-p ((manager gnus-modern-update-manager))
  "Return non-nil while a worker or local apply operation is active."
  (or (> (hash-table-count (oref manager processes)) 0)
      (oref manager apply-queue)
      (timerp (oref manager apply-timer))))

(cl-defmethod gnus-modern--force-header ((_manager gnus-modern-update-manager))
  "Redisplay visible Gnus header lines."
  (dolist (buffer (append (gnus-modern--group-buffers)
                          (gnus-modern--summary-buffers)))
    (with-current-buffer buffer
      (force-mode-line-update t))))

(cl-defmethod gnus-modern--next-text ((manager gnus-modern-update-manager))
  "Return the time remaining before the next complete update."
  (if (not (oref manager next-time))
      "not scheduled"
    (let ((seconds
           (max 0
                (float-time
                 (time-subtract
                  (oref manager next-time)
                  (current-time))))))
      (if (< seconds 60)
          "<1 minutes"
        (format "%d minutes" (ceiling (/ seconds 60.0)))))))

(cl-defmethod gnus-modern--progress-record ((manager gnus-modern-update-manager)
                                            source payload)
  "Merge worker progress PAYLOAD into the record for SOURCE."
  (let ((record (copy-sequence
                 (or (gethash source (oref manager progress))
                     (list :phase 'checking
                           :check-done 0 :check-total 0
                           :download-done 0 :download-total 0))))
        (phase (plist-get payload :phase)))
    (setq record (plist-put record :phase phase))
    (pcase phase
      ('checking
       (setq record
             (plist-put record :check-done
                        (or (plist-get payload :done) 0))
             record
             (plist-put record :check-total
                        (or (plist-get payload :total) 0))))
      ('downloading
       (setq record
             (plist-put record :download-done
                        (or (plist-get payload :done) 0))
             record
             (plist-put record :download-total
                        (or (plist-get payload :total) 0)))))
    (puthash source record (oref manager progress))))

(cl-defmethod gnus-modern--progress-text ((manager gnus-modern-update-manager))
  "Return the aggregate worker or local-apply progress text."
  (cond
   ((or (oref manager apply-queue)
        (timerp (oref manager apply-timer)))
    (format "APPLYING %d/%d"
            (oref manager apply-done)
            (oref manager apply-total)))
   ((> (hash-table-count (oref manager processes)) 0)
    (let ((checking nil)
          (check-done 0)
          (check-total 0)
          (download-done 0)
          (download-total 0))
      (maphash
       (lambda (_source record)
         (when (eq (plist-get record :phase) 'checking)
           (setq checking t))
         (setq check-done
               (+ check-done
                  (if (eq (plist-get record :phase) 'checking)
                      (or (plist-get record :check-done) 0)
                    (or (plist-get record :check-total) 0)))
               check-total
               (+ check-total
                  (or (plist-get record :check-total) 0))
               download-done
               (+ download-done
                  (or (plist-get record :download-done) 0))
               download-total
               (+ download-total
                  (or (plist-get record :download-total) 0))))
       (oref manager progress))
      (if checking
          (format "CHECKING %d/%d" check-done check-total)
        (format "DOWNLOADING %d/%d"
                download-done download-total))))
   (t nil)))

(cl-defmethod gnus-modern--header-status ((manager gnus-modern-update-manager))
  "Return the clickable background-update status for the Group header."
  (let* ((progress (gnus-modern--progress-text manager))
         (failure-count (hash-table-count (oref manager failures)))
         (text
          (cond
           (progress
            (pcase-let ((`(,label ,value)
                         (split-string progress " " t)))
              (concat
               (propertize label 'face 'gnus-modern-header-label-face)
               " "
               (propertize value 'face 'gnus-modern-update-value-face))))
           ((> failure-count 0)
            (concat
             (propertize "UPDATE FAILED"
                         'face 'gnus-modern-header-label-face)
             " "
             (propertize
              (format "%d/%d"
                      failure-count
                      (max failure-count
                           (oref manager source-total)))
              'face '(error gnus-modern-update-value-face))))
           (t
            (concat
             (propertize "NEXT UPDATE"
                         'face 'gnus-modern-header-label-face)
             " "
             (propertize (gnus-modern--next-text manager)
                         'face 'gnus-modern-update-value-face))))))
    (add-text-properties
     0 (length text)
     (list 'mouse-face 'mode-line-highlight
           'help-echo "mouse-1: update Gnus in the background"
           'keymap gnus-modern--update-header-map)
     text)
    text))

;;; Source gathering and retries

(cl-defmethod gnus-modern--sources ((_manager gnus-modern-update-manager))
  "Return background-update requests grouped by remote NNTP source."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (info (cdr gnus-newsrc-alist))
      (when (<= (gnus-info-level info) gnus-level-subscribed)
        (let* ((group (gnus-info-group info))
               (method (gnus-find-method-for-group group)))
          (when (eq (car method) 'nntp)
            (let* ((source (gnus-method-to-server method t))
                   (entry (gethash source table))
                   (spec
                    (list :group group
                          :active (copy-tree
                                   (or (gnus-active group)
                                       '(0 . 0)))
                          :read (copy-tree (gnus-info-read info))
                          :download-bodies
                          gnus-modern-update-download-bodies
                          :missing-bodies
                          (and gnus-modern-update-download-bodies
                               (gnus-modern--update-missing-bodies group)))))
              (if entry
                  (setf (plist-get entry :groups)
                        (nconc (plist-get entry :groups)
                               (list spec)))
                (puthash
                 source
                 (list :source source
                       :method method
                       :groups (list spec))
                 table)))))))
    (let (sources)
      (maphash (lambda (_source entry) (push entry sources)) table)
      (sort sources
            (lambda (left right)
              (string-lessp (plist-get left :source)
                            (plist-get right :source)))))))

(cl-defmethod gnus-modern--cancel-retry ((manager gnus-modern-update-manager)
                                         source)
  "Cancel the pending retry for SOURCE."
  (when-let* ((timer (gethash source (oref manager retry-timers))))
    (gnus-modern--update-cancel-timer timer)
    (remhash source (oref manager retry-timers))))

(cl-defmethod gnus-modern--retry-source ((manager gnus-modern-update-manager)
                                         source)
  "Retry the failed background update for SOURCE."
  (gnus-modern--cancel-retry manager source)
  (when (and (oref manager enabled-p)
             (gnus-alive-p)
             (not (gethash source (oref manager processes))))
    (if-let* ((entry
               (seq-find
                (lambda (candidate)
                  (equal (plist-get candidate :source) source))
                (gnus-modern--sources manager))))
        (gnus-modern--start-source manager entry)
      (remhash source (oref manager failures))
      (remhash source (oref manager retry-counts)))))

(cl-defmethod gnus-modern--record-failure ((manager gnus-modern-update-manager)
                                           source errors)
  "Record ERRORS for SOURCE and schedule its next retry."
  (let* ((count (1+ (or (gethash source (oref manager retry-counts))
                        0)))
         (delays (or gnus-modern-update-retry-delays
                     (list gnus-modern-update-interval)))
         (index (min (1- (max 1 count))
                     (1- (length delays))))
         (delay (max 1 (nth index delays))))
    (puthash source count (oref manager retry-counts))
    (puthash source errors (oref manager failures))
    (gnus-modern--cancel-retry manager source)
    (when (and (oref manager enabled-p) (gnus-alive-p))
      (puthash
       source
       (run-at-time delay nil
                    (lambda () (gnus-modern--retry-source manager source)))
       (oref manager retry-timers)))))

(cl-defmethod gnus-modern--record-success ((manager gnus-modern-update-manager)
                                           source)
  "Clear failure and retry state for SOURCE."
  (gnus-modern--cancel-retry manager source)
  (remhash source (oref manager failures))
  (remhash source (oref manager retry-counts)))

(cl-defmethod gnus-modern--schedule-next ((manager gnus-modern-update-manager))
  "Schedule the next complete background update."
  (gnus-modern--update-cancel-timer (oref manager periodic-timer))
  (let ((delay (max 1 gnus-modern-update-interval)))
    (oset manager next-time (time-add (current-time) delay))
    (oset manager periodic-timer
          (run-at-time delay nil
                       (lambda () (gnus-modern--periodic manager))))))

(cl-defmethod gnus-modern--periodic ((manager gnus-modern-update-manager))
  "Start one scheduled complete background update."
  (oset manager periodic-timer nil)
  (oset manager next-time nil)
  (when (and (oref manager enabled-p) (gnus-alive-p))
    (if (gnus-modern--active-p manager)
        (gnus-modern--schedule-next manager)
      (gnus-modern--update manager))))

;;; Enablement and session lifecycle

(cl-defmethod gnus-modern--install-group-binding
  ((manager gnus-modern-update-manager))
  "Install the nonblocking Group `g' binding when enabled."
  (when (and (oref manager enabled-p)
             (boundp 'gnus-group-mode-map))
    (unless (oref manager group-binding-saved-p)
      (oset manager original-group-g-binding
            (lookup-key gnus-group-mode-map (kbd "g")))
      (oset manager group-binding-saved-p t))
    (define-key gnus-group-mode-map (kbd "g") #'gnus-modern-update)))

(cl-defmethod gnus-modern--restore-group-binding
  ((manager gnus-modern-update-manager))
  "Restore the Group binding replaced by the update component."
  (when (and (oref manager group-binding-saved-p)
             (boundp 'gnus-group-mode-map))
    (define-key gnus-group-mode-map (kbd "g")
                (oref manager original-group-g-binding)))
  (oset manager original-group-g-binding nil)
  (oset manager group-binding-saved-p nil))

(cl-defmethod gnus-modern--start-initial ((manager gnus-modern-update-manager))
  "Start the first background update of the current Gnus session."
  (oset manager start-timer nil)
  (when (and (oref manager enabled-p) (gnus-alive-p))
    (gnus-modern--update manager)))

(cl-defmethod gnus-modern--start ((manager gnus-modern-update-manager))
  "Start timers for one active Gnus session."
  (gnus-modern--update-cancel-timer (oref manager start-timer))
  (gnus-modern--update-cancel-timer (oref manager header-timer))
  (oset manager header-timer
        (run-at-time 0 30 (lambda () (gnus-modern--force-header manager))))
  (oset manager start-timer
        (run-with-idle-timer
         0.1 nil (lambda () (gnus-modern--start-initial manager)))))

(cl-defmethod gnus-modern--update ((manager gnus-modern-update-manager))
  "Run one complete background update through MANAGER."
  (unless (gnus-alive-p)
    (user-error "Gnus is not running"))
  (if (gnus-modern--active-p manager)
      (message "%s" (or (gnus-modern--progress-text manager)
                        "Gnus update already in progress"))
    (let ((sources (gnus-modern--sources manager)))
      (oset manager source-total (length sources))
      (gnus-modern--schedule-next manager)
      (if (not sources)
          (message "No subscribed NNTP groups to update")
        (dolist (entry sources)
          (gnus-modern--start-source manager entry))
        (gnus-modern--force-header manager)))))

(cl-defmethod gnus-modern--enable ((manager gnus-modern-update-manager))
  "Enable nonblocking background updates while Gnus is active."
  (unless (oref manager enabled-p)
    (oset manager enabled-p t)
    (add-hook 'gnus-started-hook #'gnus-modern--update-start-hook)
    (add-hook 'gnus-exit-gnus-hook #'gnus-modern--update-stop-hook)
    (with-eval-after-load 'gnus-group
      (gnus-modern--install-group-binding manager))
    (when (gnus-alive-p)
      (gnus-modern--start manager)))
  t)

(cl-defmethod gnus-modern--disable ((manager gnus-modern-update-manager))
  "Disable background Gnus updates and restore the native Group binding."
  (when (oref manager enabled-p)
    (oset manager enabled-p nil)
    (remove-hook 'gnus-started-hook #'gnus-modern--update-start-hook)
    (remove-hook 'gnus-exit-gnus-hook #'gnus-modern--update-stop-hook)
    (gnus-modern--stop manager)
    (gnus-modern--restore-group-binding manager)))

(cl-defmethod cl-print-object ((object gnus-modern-update-manager) stream)
  "Print a compact description of OBJECT to STREAM."
  (princ (format "#<update-manager %s workers=%d queue=%d>"
                 (if (oref object enabled-p) "enabled" "disabled")
                 (hash-table-count (oref object processes))
                 (length (oref object apply-queue)))
         stream))

;;; Public commands

(defun gnus-modern--update-start-hook ()
  "Start background update timers for the current Gnus session."
  (gnus-modern--start gnus-modern--update-manager))

(defun gnus-modern--update-stop-hook ()
  "Stop background update work owned by the current Gnus session."
  (gnus-modern--stop gnus-modern--update-manager))

;;;###autoload
(defun gnus-modern-update ()
  "Update Gnus remotely without blocking the main Emacs process."
  (interactive)
  (gnus-modern--update gnus-modern--update-manager))

;;;###autoload
(defun gnus-modern-update-enable ()
  "Enable nonblocking background updates while Gnus is active."
  (interactive)
  (gnus-modern--enable gnus-modern--update-manager))

;;;###autoload
(defun gnus-modern-update-disable ()
  "Disable background Gnus updates and restore the native Group binding."
  (interactive)
  (gnus-modern--disable gnus-modern--update-manager))

;;;; Pure helpers

(defun gnus-modern--update-missing-bodies (group)
  "Return unread article numbers in GROUP absent from the Agent."
  (require 'gnus-agent)
  (let ((unread (gnus-list-of-unread-articles group))
        (gnus-agent-article-alist nil))
    (gnus-agent-load-alist group)
    (seq-remove
     (lambda (article)
       (or (cdr (assq article gnus-agent-article-alist))
           (file-exists-p
            (gnus-agent-article-name
             (number-to-string article) group))))
     unread)))

(defun gnus-modern--update-cancel-timer (timer)
  "Cancel TIMER when it is live."
  (when (timerp timer)
    (cancel-timer timer)))

(defun gnus-modern--update-method-address (method)
  "Return the network address configured by NNTP METHOD."
  (or (cadr (assq 'nntp-address (cddr method)))
      (cadr method)))

(defun gnus-modern--update-credential (method)
  "Return a serializable authentication record for NNTP METHOD."
  (require 'auth-source)
  (when-let* ((entry
               (car
                (auth-source-search
                 :max 1
                 :host (gnus-modern--update-method-address method)
                 :require '(:user :secret))))
              (secret (plist-get entry :secret))
              (password
               (if (functionp secret)
                   (funcall secret)
                 secret)))
    (list :host (plist-get entry :host)
          :port (plist-get entry :port)
          :user (plist-get entry :user)
          :secret password
          :force t)))

(defun gnus-modern--update-overview-articles (file)
  "Return sorted article numbers present in overview FILE."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (articles)
        (while (re-search-forward "^\\([0-9]+\\)\t" nil t)
          (push (string-to-number (match-string 1)) articles))
        (nreverse articles)))))

(defun gnus-modern--update-summary-window-states (buffer)
  "Return visible-window positions anchored to articles in BUFFER."
  (mapcar
   (lambda (window)
     (let ((start (window-start window)))
       (list
        window
        (or (get-text-property start 'gnus-intangible buffer)
            (with-current-buffer buffer
              (save-excursion
                (goto-char start)
                (gnus-summary-article-number))))
        (window-hscroll window))))
   (get-buffer-window-list buffer nil t)))

(defun gnus-modern--update-restore-summary-windows (buffer states)
  "Restore BUFFER windows from article-anchored STATES."
  (dolist (state states)
    (pcase-let ((`(,window ,article ,hscroll) state))
      (when (and (window-live-p window)
                 (eq (window-buffer window) buffer))
        (when article
          (with-current-buffer buffer
            (save-excursion
              (when (gnus-summary-goto-subject article nil t)
                (set-window-start window
                                  (line-beginning-position))))))
        (set-window-hscroll window hscroll)))))

(defun gnus-modern--update-current-summary-article ()
  "Return the article anchoring point in the current Summary buffer."
  (or (get-text-property (point) 'gnus-intangible)
      (gnus-summary-article-number)))

(defun gnus-modern--update-group-identity-at (buffer position)
  "Return the Group or Topic identity at POSITION in BUFFER."
  (with-current-buffer buffer
    (list (get-text-property position 'gnus-group)
          (get-text-property position 'gnus-topic))))

(defun gnus-modern--update-find-group-identity (group topic)
  "Return the current buffer position matching GROUP or TOPIC."
  (save-excursion
    (goto-char (point-min))
    (catch 'position
      (while (not (eobp))
        (when (or (and group
                       (equal group
                              (get-text-property
                               (point) 'gnus-group)))
                  (and topic
                       (equal topic
                              (get-text-property
                               (point) 'gnus-topic))))
          (throw 'position (point)))
        (forward-line 1))
      nil)))

(provide 'gnus-modern-update)
;;; gnus-modern-update.el ends here
