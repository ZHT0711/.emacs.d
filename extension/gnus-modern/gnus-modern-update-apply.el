;;; gnus-modern-update-apply.el --- Staged update application  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Parent-side machinery that applies worker results without blocking
;; the main Emacs process:

;; - process plumbing: protocol line parsing, filters, sentinels,
;;   watchdog, and spawning one isolated worker per remote source;
;; - staged application: metadata and body operations are enqueued and
;;   applied in short idle slices (`gnus-modern--apply-slice'), with
;;   live Agent, Summary, and Group buffers refreshed incrementally;
;; - session shutdown: `gnus-modern--stop' tears down processes,
;;   timers, and staged state.

;; Methods here dispatch on `gnus-modern-update-manager' (defined in
;; `gnus-modern-update-manager.el').  Methods defined in
;; `gnus-modern-update.el' are referenced at runtime only.

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

(declare-function gnus-modern--force-header
                  "gnus-modern-update" (manager))
(declare-function gnus-modern--progress-record
                  "gnus-modern-update" (manager source payload))
(declare-function gnus-modern--record-failure
                  "gnus-modern-update" (manager source errors))
(declare-function gnus-modern--record-success
                  "gnus-modern-update" (manager source))
(declare-function gnus-modern--cancel-retry
                  "gnus-modern-update" (manager source))
(declare-function gnus-modern--update-cancel-timer
                  "gnus-modern-update" (timer))
(declare-function gnus-modern--update-credential
                  "gnus-modern-update" (method))
(declare-function gnus-modern--update-method-address
                  "gnus-modern-update" (method))
(declare-function gnus-modern--update-overview-articles
                  "gnus-modern-update" (file))
(declare-function gnus-modern--update-summary-window-states
                  "gnus-modern-update" (buffer))
(declare-function gnus-modern--update-restore-summary-windows
                  "gnus-modern-update" (buffer states))
(declare-function gnus-modern--update-current-summary-article
                  "gnus-modern-update" ())
(declare-function gnus-modern--update-group-identity-at
                  "gnus-modern-update" (buffer position))
(declare-function gnus-modern--update-find-group-identity
                  "gnus-modern-update" (group topic))

(declare-function gnus-data-number "gnus-sum" (data))
(declare-function gnus-summary-goto-subject
                  "gnus-sum" (article &optional force silent))
(declare-function gnus-summary-insert-articles "gnus-sum" (articles))
(declare-function gnus-summary-limit "gnus-sum" (articles))
(declare-function gnus-group-list-groups
                  "gnus-group"
                  (&optional level unread lowest update-level))
(declare-function gnus-group-real-name "gnus-group" (group))
(declare-function gnus-get-unread-articles-in-group
                  "gnus-start" (info active &optional update))
(declare-function gnus-get-info "gnus-start" (group))
(declare-function gnus-set-active "gnus" (group active))
(declare-function auth-source-search "auth-source" (&rest spec))
(declare-function gnus-agent-braid-nov "gnus-agent" (articles file))
(declare-function gnus-agent-check-overview-buffer
                  "gnus-agent" (&optional buffer))
(declare-function gnus-agent-create-buffer "gnus-agent" ())
(declare-function gnus-agent-load-alist "gnus-agent" (group))
(declare-function gnus-agent-save-alist
                  "gnus-agent" (group &optional articles state))
(declare-function gnus-agent-save-group-info
                  "gnus-agent" (method group active))
(declare-function gnus-sorted-nunion "gnus-range" (list1 list2))

(defvar gnus-agent)
(defvar gnus-agent-article-alist)
(defvar gnus-agent-cache)
(defvar gnus-agent-directory)
(defvar gnus-agent-file-coding-system)
(defvar gnus-agent-overview-buffer)
(defvar gnus-command-method)
(defvar gnus-group-buffer)
(defvar gnus-group-list-mode)
(defvar gnus-newsgroup-active)
(defvar gnus-newsgroup-data)
(defvar gnus-newsgroup-highest)
(defvar gnus-newsgroup-unreads)
(defvar auth-sources)
(defvar nntp-server-buffer)

(defconst gnus-modern--update-apply-time-budget 0.01
  "Maximum seconds spent in one staged-result application slice.")

;;; Worker process plumbing

(cl-defmethod gnus-modern--process-line ((manager gnus-modern-update-manager)
                                         process line)
  "Handle one protocol LINE received from PROCESS."
  (cond
   ((string-prefix-p "GNUS-MODERN-PROGRESS " line)
    (when-let* ((payload
                 (ignore-errors
                   (read
                    (substring
                     line (length "GNUS-MODERN-PROGRESS "))))))
      (gnus-modern--progress-record
       manager (process-get process 'gnus-modern-source)
       payload)
      (gnus-modern--force-header manager)))
   ((string-prefix-p "GNUS-MODERN-RESULT " line)
    (process-put
     process 'gnus-modern-result
     (ignore-errors
       (read
        (substring line (length "GNUS-MODERN-RESULT "))))))))

(cl-defmethod gnus-modern--process-filter ((manager gnus-modern-update-manager)
                                           process output)
  "Consume protocol OUTPUT from background update PROCESS."
  (gnus-modern--update-reset-watchdog process)
  (let ((pending (concat (or (process-get process 'gnus-modern-pending) "")
                         output))
        newline)
    (while (setq newline (string-search "\n" pending))
      (gnus-modern--process-line
       manager process (substring pending 0 newline))
      (setq pending (substring pending (1+ newline))))
    (process-put process 'gnus-modern-pending pending)))

(cl-defmethod gnus-modern--finish-process ((manager gnus-modern-update-manager)
                                           process event)
  "Finalize background PROCESS after EVENT."
  (when (memq (process-status process) '(exit signal failed))
    (when-let* ((pending (process-get process 'gnus-modern-pending))
                ((not (string-empty-p pending))))
      (gnus-modern--process-line manager process pending))
    (gnus-modern--update-cancel-timer
     (process-get process 'gnus-modern-watchdog))
    (let* ((source (process-get process 'gnus-modern-source))
           (stage (process-get process 'gnus-modern-stage))
           (result (process-get process 'gnus-modern-result)))
      (when (eq process (gethash source (oref manager processes)))
        (remhash source (oref manager processes)))
      (cond
       ((and result
             (= (or (plist-get result :protocol) -1)
                gnus-modern--update-protocol-version)
             (not (plist-get result :fatal)))
        (gnus-modern--enqueue-result manager result))
       (t
        (let ((error
               (or (plist-get result :fatal)
                   (gnus-modern--update-process-error process event))))
          (gnus-modern--record-failure manager source (list error))
          (remhash source (oref manager progress))
          (gnus-modern--update-delete-stage stage))))
      (dolist (buffer (list (process-buffer process)
                            (process-get process 'gnus-modern-stderr)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))
      (gnus-modern--force-header manager))))

(cl-defmethod gnus-modern--process-sentinel ((manager gnus-modern-update-manager)
                                             process event)
  "Dispatch update PROCESS completion described by EVENT."
  (gnus-modern--finish-process manager process event))

(cl-defmethod gnus-modern--start-source ((manager gnus-modern-update-manager)
                                         entry)
  "Start the isolated worker described by source ENTRY."
  (let* ((source (plist-get entry :source))
         (stage (make-temp-file "gnus-modern-update-" t))
         (request-file (expand-file-name "request.el" stage))
         (stdout (generate-new-buffer
                  (format " *gnus-modern-update %s*" source)))
         (stderr (generate-new-buffer
                  (format " *gnus-modern-update %s stderr*" source)))
         (request
          (gnus-modern--update-source-request manager entry stage))
         process)
    (gnus-modern--cancel-retry manager source)
    (condition-case err
        (progn
          (with-temp-file request-file
            (insert (prin1-to-string request)))
          (setq process
                (gnus-modern--update-spawn-worker
                 manager source request-file stdout stderr))
          (process-put process 'gnus-modern-source source)
          (process-put process 'gnus-modern-stage stage)
          (process-put process 'gnus-modern-stderr stderr)
          (puthash source process (oref manager processes))
          (puthash
           source
           (list :phase 'checking
                 :check-done 0
                 :check-total (length (plist-get entry :groups))
                 :download-done 0
                 :download-total 0)
           (oref manager progress))
          (gnus-modern--update-reset-watchdog process))
      (error
       (when (process-live-p process)
         (delete-process process))
       (dolist (buffer (list stdout stderr))
         (when (buffer-live-p buffer)
           (kill-buffer buffer)))
       (gnus-modern--update-delete-stage stage)
       (gnus-modern--record-failure
        manager source (list (error-message-string err)))))))

(defun gnus-modern--update-source-request (_manager entry stage)
  "Return the serializable update request for ENTRY and STAGE."
  (list :protocol gnus-modern--update-protocol-version
        :source (plist-get entry :source)
        :method (plist-get entry :method)
        :groups (plist-get entry :groups)
        :stage stage
        :auth-sources auth-sources
        :auth-source-pass-extra-query-keywords
        (and (boundp 'auth-source-pass-extra-query-keywords)
             auth-source-pass-extra-query-keywords)
        :credential
        (gnus-modern--update-credential
         (plist-get entry :method))))

(defun gnus-modern--update-spawn-worker (manager source request-file
                                                 stdout stderr)
  "Spawn the update worker for SOURCE with REQUEST-FILE.
Write its standard output to STDOUT and its errors to STDERR."
  (make-process
   :name (format "gnus-modern-update-%s" source)
   :buffer stdout
   :stderr stderr
   :command (append
             (gnus-modern--update-worker-command)
             (list request-file))
   :coding 'utf-8-unix
   :connection-type 'pipe
   :filter (lambda (process output)
             (gnus-modern--process-filter
              manager process output))
   :sentinel (lambda (process event)
               (gnus-modern--process-sentinel
                manager process event))
   :noquery t))

;;; Staged application

(cl-defmethod gnus-modern--merge-overview
  ((_manager gnus-modern-update-manager) stage method group header-articles)
  "Merge staged overview data for GROUP through METHOD.
STAGE is the worker Agent root.  HEADER-ARTICLES contains the
requested header numbers.  Return the numbers actually available."
  (require 'gnus-agent)
  (let* ((live-directory gnus-agent-directory)
         (stage-file
          (gnus-modern--update-agent-file
           stage method group ".overview"))
         (live-file
          (gnus-modern--update-agent-file
           live-directory method group ".overview"))
         (available
          (seq-intersection
           header-articles
           (or (gnus-modern--update-overview-articles stage-file) nil)
           #'=)))
    (when available
      (gnus-agent-create-buffer)
      (with-current-buffer gnus-agent-overview-buffer
        (erase-buffer)
        (insert-file-contents stage-file))
      (let ((gnus-command-method method))
        (gnus-agent-braid-nov available live-file)
        (with-current-buffer nntp-server-buffer
          (gnus-agent-check-overview-buffer)
          (make-directory (file-name-directory live-file) t)
          (let ((coding-system-for-write
                 gnus-agent-file-coding-system))
            (write-region (point-min) (point-max)
                          live-file nil 'silent)))
        (let ((gnus-agent-article-alist nil))
          (gnus-agent-load-alist group)
          (gnus-agent-save-alist group available nil))))
    available))

(cl-defmethod gnus-modern--apply-metadata
  ((manager gnus-modern-update-manager) _source method stage plan)
  "Apply active and overview metadata in PLAN from STAGE through METHOD."
  (let* ((group (plist-get plan :group))
         (active (plist-get plan :active))
         (available
          (gnus-modern--merge-overview
           manager stage method group
           (plist-get plan :header-articles)))
         (info (gnus-get-info group)))
    (setf (plist-get plan :available-headers) available)
    (when (and info active)
      (gnus-set-active group (copy-tree active))
      (gnus-get-unread-articles-in-group info active)
      (let ((gnus-command-method method))
        (gnus-agent-save-group-info
         method (gnus-group-real-name group) active)))))

(cl-defmethod gnus-modern--copy-body
  ((manager gnus-modern-update-manager) _source method stage group article)
  "Copy staged ARTICLE for GROUP through METHOD into the live Agent."
  (let* ((live-directory gnus-agent-directory)
         (name (number-to-string article))
         (source-file
          (gnus-modern--update-agent-file
           stage method group name))
         (destination
          (gnus-modern--update-agent-file
           live-directory method group name)))
    (when (file-readable-p source-file)
      (unless (file-exists-p destination)
        (make-directory (file-name-directory destination) t)
        (copy-file source-file destination))
      (puthash
       group
       (cons article
             (gethash group (oref manager imported-bodies)))
       (oref manager imported-bodies)))))

(cl-defmethod gnus-modern--refresh-summary
  ((_manager gnus-modern-update-manager) group active new-articles)
  "Insert NEW-ARTICLES for GROUP locally and record ACTIVE."
  (dolist (buffer (gnus-modern--summary-buffers))
    (with-current-buffer buffer
      (when (equal gnus-newsgroup-name group)
        (let ((selected (gnus-modern--update-current-summary-article))
              (states
               (gnus-modern--update-summary-window-states buffer))
              (old
               (sort
                (mapcar #'gnus-data-number gnus-newsgroup-data)
                #'<)))
          (setq gnus-newsgroup-active (copy-tree active)
                gnus-newsgroup-highest (cdr active))
          (when new-articles
            (let ((gnus-agent-cache t))
              (gnus-summary-insert-articles new-articles))
            (setq gnus-newsgroup-unreads
                  (gnus-sorted-nunion
                   gnus-newsgroup-unreads new-articles))
            (gnus-summary-limit
             (gnus-sorted-nunion old new-articles)))
          (when selected
            (gnus-summary-goto-subject selected nil t))
          (gnus-modern--update-restore-summary-windows
           buffer states))))))

(cl-defmethod gnus-modern--finish-group
  ((manager gnus-modern-update-manager) _source method _stage plan)
  "Finalize live Agent and Summary state described by PLAN through METHOD."
  (let* ((group (plist-get plan :group))
         (imported
          (sort
           (delete-dups
            (gethash group (oref manager imported-bodies)))
           #'<))
         (available (plist-get plan :available-headers))
         (new-articles
          (seq-intersection
           (plist-get plan :new-articles)
           available #'=)))
    (remhash group (oref manager imported-bodies))
    (when imported
      (let ((gnus-command-method method)
            (gnus-agent-article-alist nil))
        (gnus-agent-load-alist group)
        (gnus-agent-save-alist
         group imported (time-to-days nil))))
    (gnus-modern--refresh-summary
     manager group (plist-get plan :active) new-articles)))

(cl-defmethod gnus-modern--refresh-group ((_manager gnus-modern-update-manager))
  "Rebuild the live Group buffer from locally updated Gnus state."
  (when (and (boundp 'gnus-group-buffer)
             (buffer-live-p (get-buffer gnus-group-buffer)))
    (with-current-buffer gnus-group-buffer
      (let* ((identity
              (gnus-modern--update-group-identity-at
               (current-buffer) (point)))
             (windows (get-buffer-window-list (current-buffer) nil t))
             (states
              (mapcar
               (lambda (window)
                 (append
                  (list window)
                  (gnus-modern--update-group-identity-at
                   (current-buffer) (window-start window))
                  (list (window-hscroll window))))
               windows)))
        (gnus-group-list-groups
         (car gnus-group-list-mode)
         (cdr gnus-group-list-mode))
        (when-let* ((position
                     (gnus-modern--update-find-group-identity
                      (car identity) (cadr identity))))
          (goto-char position))
        (dolist (state states)
          (pcase-let ((`(,window ,group ,topic ,hscroll) state))
            (when (and (window-live-p window)
                       (eq (window-buffer window) (current-buffer)))
              (when-let* ((position
                           (gnus-modern--update-find-group-identity
                            group topic)))
                (set-window-start window position))
              (set-window-hscroll window hscroll))))))))

(cl-defmethod gnus-modern--finish-source
  ((manager gnus-modern-update-manager) source stage worker-errors)
  "Finish SOURCE application from STAGE with WORKER-ERRORS."
  (let ((errors
         (nconc
          (copy-sequence worker-errors)
          (nreverse
           (gethash source (oref manager apply-errors))))))
    (remhash source (oref manager apply-errors))
    (remhash source (oref manager progress))
    (condition-case err
        (gnus-modern--refresh-group manager)
      (error
       (push (error-message-string err) errors)))
    (if errors
        (gnus-modern--record-failure manager source errors)
      (gnus-modern--record-success manager source))
    (gnus-modern--update-delete-stage stage)
    (gnus-modern--force-header manager)))

(cl-defmethod gnus-modern--apply-operation ((manager gnus-modern-update-manager)
                                            operation)
  "Apply one staged update OPERATION."
  (pcase operation
    (`(metadata ,source ,method ,stage ,plan)
     (gnus-modern--apply-metadata
      manager source method stage plan))
    (`(body ,source ,method ,stage ,group ,article)
     (gnus-modern--copy-body
      manager source method stage group article))
    (`(finish-group ,source ,method ,stage ,plan)
     (gnus-modern--finish-group
      manager source method stage plan))
    (`(finish-source ,source ,stage ,errors)
     (gnus-modern--finish-source
      manager source stage errors))))

(cl-defmethod gnus-modern--schedule-apply ((manager gnus-modern-update-manager))
  "Schedule the next idle slice that applies staged update data."
  (unless (timerp (oref manager apply-timer))
    (oset manager apply-timer
          (run-with-idle-timer
           0.05 nil (lambda () (gnus-modern--apply-slice manager))))))

(cl-defmethod gnus-modern--apply-slice ((manager gnus-modern-update-manager))
  "Apply staged update operations within a short time budget."
  (oset manager apply-timer nil)
  (let ((deadline (+ (float-time)
                     gnus-modern--update-apply-time-budget)))
    (while (and (oref manager apply-queue)
                (< (float-time) deadline)
                (not (input-pending-p)))
      (let* ((operation (pop (oref manager apply-queue)))
             (source (nth 1 operation)))
        (condition-case err
            (gnus-modern--apply-operation manager operation)
          (error
           (puthash
            source
            (cons (error-message-string err)
                  (gethash source (oref manager apply-errors)))
            (oref manager apply-errors))))
        (oset manager apply-done
              (1+ (oref manager apply-done))))))
  (if (oref manager apply-queue)
      (gnus-modern--schedule-apply manager)
    (oset manager apply-done 0)
    (oset manager apply-total 0))
  (gnus-modern--force-header manager))

(cl-defmethod gnus-modern--enqueue-result ((manager gnus-modern-update-manager)
                                           result)
  "Queue local application operations for worker RESULT."
  (let ((source (plist-get result :source))
        (method (plist-get result :method))
        (stage (plist-get result :stage))
        operations)
    (dolist (original-plan (plist-get result :groups))
      (let ((plan
             (plist-put original-plan :available-headers nil)))
        (push (list 'metadata source method stage plan)
              operations)
        (dolist (article (plist-get plan :fetched-bodies))
          (push (list 'body source method stage
                      (plist-get plan :group) article)
                operations))
        (push (list 'finish-group source method stage plan)
              operations)))
    (push (list 'finish-source source stage
                (plist-get result :errors))
          operations)
    (setf operations (nreverse operations)
          (oref manager apply-total)
          (+ (oref manager apply-total)
             (length operations))
          (oref manager apply-queue)
          (nconc (oref manager apply-queue) operations))
    (gnus-modern--schedule-apply manager)
    (gnus-modern--force-header manager)))

;;; Session shutdown

(cl-defmethod gnus-modern--stop ((manager gnus-modern-update-manager))
  "Stop all background update work owned by the current Gnus session."
  (dolist (timer (list (oref manager start-timer)
                       (oref manager periodic-timer)
                       (oref manager header-timer)
                       (oref manager apply-timer)))
    (gnus-modern--update-cancel-timer timer))
  (oset manager start-timer nil)
  (oset manager periodic-timer nil)
  (oset manager header-timer nil)
  (oset manager apply-timer nil)
  (oset manager next-time nil)
  (maphash
   (lambda (_source timer)
     (gnus-modern--update-cancel-timer timer))
   (oref manager retry-timers))
  (clrhash (oref manager retry-timers))
  (gnus-modern--update-stop-processes manager)
  (gnus-modern--update-stop-apply manager)
  (dolist (table (list (oref manager progress)
                       (oref manager failures)
                       (oref manager retry-counts)
                       (oref manager imported-bodies)
                       (oref manager apply-errors)))
    (clrhash table))
  (gnus-modern--force-header manager))

(cl-defmethod gnus-modern--update-stop-processes
  ((manager gnus-modern-update-manager))
  "Terminate live worker processes owned by MANAGER."
  (maphash
   (lambda (_source process)
     (gnus-modern--update-cancel-timer
      (process-get process 'gnus-modern-watchdog))
     (set-process-sentinel process #'ignore)
     (when (process-live-p process)
       (delete-process process))
     (gnus-modern--update-delete-stage
      (process-get process 'gnus-modern-stage))
     (dolist (buffer (list (process-buffer process)
                           (process-get process 'gnus-modern-stderr)))
       (when (buffer-live-p buffer)
         (kill-buffer buffer))))
   (oref manager processes))
  (clrhash (oref manager processes)))

(cl-defmethod gnus-modern--update-stop-apply
  ((manager gnus-modern-update-manager))
  "Discard staged application state owned by MANAGER."
  (let (stages)
    (dolist (operation (oref manager apply-queue))
      (when-let* ((stage
                   (pcase operation
                     (`(metadata ,_ ,_ ,value . ,_) value)
                     (`(body ,_ ,_ ,value . ,_) value)
                     (`(finish-group ,_ ,_ ,value . ,_) value)
                     (`(finish-source ,_ ,value . ,_) value))))
        (cl-pushnew stage stages :test #'equal)))
    (mapc #'gnus-modern--update-delete-stage stages))
  (oset manager apply-queue nil)
  (oset manager apply-done 0)
  (oset manager apply-total 0))

;;;; Process plumbing helpers

(defun gnus-modern--update-worker-command ()
  "Return the command used to start an isolated update worker."
  (let ((library (or (symbol-file 'gnus-modern-update-worker 'defun)
                     load-file-name
                     buffer-file-name)))
    (unless library
      (error "Cannot locate gnus-modern for the update worker"))
    (list (expand-file-name invocation-name invocation-directory)
          "-Q" "--batch"
          "-L" (file-name-directory library)
          "-l" library
          "-f" "gnus-modern-update-worker")))

(defun gnus-modern--update-reset-watchdog (process)
  "Reset the inactivity watchdog belonging to PROCESS."
  (gnus-modern--update-cancel-timer
   (process-get process 'gnus-modern-watchdog))
  (process-put
   process 'gnus-modern-watchdog
   (run-at-time
    (max 1 gnus-modern-update-stall-timeout) nil
    #'gnus-modern--update-worker-stalled process)))

(defun gnus-modern--update-worker-stalled (process)
  "Terminate PROCESS after it stops reporting progress."
  (when (process-live-p process)
    (process-put process 'gnus-modern-stalled t)
    (delete-process process)))

(defun gnus-modern--update-delete-stage (stage)
  "Delete the private temporary update directory STAGE."
  (when (and (stringp stage)
             (file-directory-p stage)
             (string-prefix-p
              (expand-file-name "gnus-modern-update-"
                                temporary-file-directory)
              (expand-file-name stage)))
    (delete-directory stage t)))

(defun gnus-modern--update-process-error (process event)
  "Return a concise failure description for PROCESS and EVENT."
  (let* ((buffer (process-get process 'gnus-modern-stderr))
         (details
          (and (buffer-live-p buffer)
               (with-current-buffer buffer
                 (string-trim (buffer-string))))))
    (cond
     ((process-get process 'gnus-modern-stalled)
      (format "No worker progress for %d seconds"
              gnus-modern-update-stall-timeout))
     ((and details (not (string-empty-p details)))
      (truncate-string-to-width details 300 nil nil "..."))
     (t (string-trim event)))))

(provide 'gnus-modern-update-apply)
;;; gnus-modern-update-apply.el ends here
