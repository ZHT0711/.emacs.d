;;; gnus-modern-update-worker.el --- Background update worker  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; The `gnus-modern-update-worker' class runs inside an isolated
;; Emacs subprocess: it reads a request file, rebuilds a private
;; Agent root under a temporary stage directory, scans every requested
;; group through its NNTP method, fetches new headers and bodies, and
;; emits `GNUS-MODERN-PROGRESS' / `GNUS-MODERN-RESULT' messages to
;; standard output.  The parent side (`gnus-modern-update.el',
;; `gnus-modern-update-apply.el') consumes those messages.

;; Enable with `gnus-modern-update-enable'; run one update with
;; `gnus-modern-update'.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'eieio)
(require 'mail-parse)
(require 'gnus)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-update-manager)

(declare-function mail-decode-encoded-word-string "mail-parse" (string))
(declare-function gnus-activate-group
                  "gnus-start"
                  (group &optional scan dont-check method dont-sub-check))
(declare-function gnus-info-make "gnus-start" (group level read &optional method))
(declare-function gnus-make-hashtable "gnus-util" (&optional size))
(declare-function gnus-make-hashtable-from-newsrc-alist "gnus-start" ())
(declare-function gnus-status-message "gnus" (command-method))
(declare-function gnus-agent-fetch-articles "gnus-agent" (group articles))
(declare-function gnus-agent-retrieve-headers
                  "gnus-agent" (articles group &optional fetch-old))
(declare-function gnus-agent-article-name "gnus-agent" (article group))
(declare-function auth-source-pass-enable "auth-source-pass" ())

(defvar auth-sources)
(defvar auth-source-pass-extra-query-keywords)
(defvar command-line-args-left)
(defvar gnus-active-hashtb)
(defvar gnus-agent)
(defvar gnus-agent-cache)
(defvar gnus-agent-covered-methods)
(defvar gnus-agent-directory)
(defvar gnus-command-method)
(defvar gnus-directory)
(defvar gnus-home-directory)
(defvar gnus-newsrc-alist)
(defvar gnus-opened-servers)
(defvar gnus-plugged)
(defvar gnus-select-method)
(defvar gnus-secondary-select-methods)
(defvar gnus-startup-file)
(defvar gnus-use-cache)

(defconst gnus-modern--update-protocol-version 2
  "Protocol version shared with background update workers.")

(defconst gnus-modern--update-header-chunk-size 200
  "Maximum number of headers fetched between progress reports.")

(defconst gnus-modern--update-body-chunk-size 10
  "Maximum number of article bodies fetched between progress reports.")

;;; Worker class (runs in an isolated Emacs subprocess)

(defclass gnus-modern-update-worker-instance ()
  ((protocol-version :initform nil
                     :documentation "Requested protocol version.")
   (source :initform nil
           :documentation "Gnus server name being updated.")
   (method :initform nil
           :documentation "NNTP method of the source.")
   (groups :initform nil
           :documentation "Group specs to scan.")
   (stage :initform nil
          :documentation "Private temporary Agent root.")
   (auth-sources :initform nil
                 :documentation "Auth-source configuration.")
   (auth-source-pass-extra-query-keywords :initform nil
                                          :documentation
                                          "Extra auth-source-pass query keywords.")
   (credential :initform nil
               :documentation "Serialized authentication record.")
   (auth-source-search-function :initform nil
                                :documentation
                                "Original `auth-source-search' function."))
  :documentation "Isolated Gnus update worker of gnus-modern.")

(cl-defmethod gnus-modern--read-request ((worker gnus-modern-update-worker-instance) file)
  "Load the background update request from FILE into WORKER."
  (let ((request
         (with-temp-buffer
           (insert-file-contents file)
           (goto-char (point-min))
           (read (current-buffer)))))
    (oset worker protocol-version (plist-get request :protocol))
    (oset worker source (plist-get request :source))
    (oset worker method (plist-get request :method))
    (oset worker groups (plist-get request :groups))
    (oset worker stage (plist-get request :stage))
    (oset worker auth-sources (plist-get request :auth-sources))
    (oset worker auth-source-pass-extra-query-keywords
          (plist-get request :auth-source-pass-extra-query-keywords))
    (oset worker credential (plist-get request :credential))))

(cl-defmethod gnus-modern--auth-source-search
  ((worker gnus-modern-update-worker-instance) &rest spec)
  "Return the worker credential or search authentication using SPEC."
  (if (oref worker credential)
      (list (oref worker credential))
    (apply (oref worker auth-source-search-function) spec)))

(defun gnus-modern--scan-groups (groups method)
  "Scan GROUPS through METHOD and return fetch plans."
  (let ((done 0)
        (total (length groups))
        plans
        errors)
    (dolist (spec groups)
      (let ((group (plist-get spec :group)))
        (pcase-let ((`(,plan . ,error)
                     (gnus-modern--scan-group spec method)))
          (if plan
              (push plan plans)
            (push (cons group error) errors))))
      (setq done (1+ done))
      (gnus-modern--update-worker-emit
       "PROGRESS"
       (list :phase 'checking :done done :total total)))
    (list (nreverse plans) (nreverse errors))))

(defun gnus-modern--scan-group (spec method)
  "Scan one group SPEC through METHOD.
Return a cons of the fetch plan and nil, or of nil and the error."
  (let ((group (plist-get spec :group)))
    (condition-case err
        (if-let* ((active (gnus-activate-group group nil nil method)))
            (let* ((old-high (or (cdr (plist-get spec :active)) 0))
                   (new-articles
                    (and (<= (1+ old-high) (or (cdr active) -1))
                         (number-sequence
                          (1+ old-high) (or (cdr active) -1)))))
              (cons
               (gnus-modern--scan-group-plan
                spec group active new-articles)
               nil))
          (cons nil
                (let ((status
                       (string-trim
                        (or (ignore-errors
                              (gnus-status-message method))
                            ""))))
                  (if (string-empty-p status)
                      "Cannot activate group"
                    status))))
      (error (cons nil (error-message-string err))))))

(defun gnus-modern--scan-group-plan (spec group active new-articles)
  "Return the fetch plan for GROUP from SPEC, ACTIVE, and NEW-ARTICLES."
  (let* ((low (or (car active) 0))
         (high (or (cdr active) -1))
         (body-articles
          (and (plist-get spec :download-bodies)
               (seq-filter
                (lambda (article)
                  (and (integerp article)
                       (<= low article high)))
                (sort
                 (delete-dups
                  (append
                   (copy-sequence (plist-get spec :missing-bodies))
                   (copy-sequence new-articles)))
                 #'<)))))
    (list :group group
          :active active
          :new-articles new-articles
          :header-articles (copy-sequence body-articles)
          :body-articles body-articles)))

(defun gnus-modern--fetch-group (plan completed total)
  "Fetch the staged data described by PLAN.
COMPLETED and TOTAL describe body-download progress.  Return a
pair containing the fetched body numbers and any errors."
  (let* ((group (plist-get plan :group))
         (headers (plist-get plan :header-articles))
         (bodies (plist-get plan :body-articles))
         fetched
         errors)
    (dolist (chunk (seq-partition
                    headers gnus-modern--update-header-chunk-size))
      (condition-case err
          (gnus-agent-retrieve-headers chunk group)
        (error
         (push (cons group (error-message-string err)) errors)))
      (gnus-modern--update-worker-emit
       "PROGRESS"
       (list :phase 'downloading
             :done completed :total total)))
    (dolist (chunk (seq-partition
                    bodies gnus-modern--update-body-chunk-size))
      (condition-case err
          (setq fetched
                (nconc fetched
                       (gnus-agent-fetch-articles group chunk)))
        (error
         (push (cons group (error-message-string err)) errors)))
      (setq completed (+ completed (length chunk)))
      (gnus-modern--update-worker-emit
       "PROGRESS"
       (list :phase 'downloading
             :done completed :total total)))
    (list fetched (nreverse errors) completed)))

(cl-defmethod gnus-modern--update-worker-protocol-check
  ((worker gnus-modern-update-worker-instance))
  "Signal an error when WORKER speaks an unsupported protocol."
  (unless (= (or (oref worker protocol-version) -1)
             gnus-modern--update-protocol-version)
    (error "Unsupported gnus-modern update protocol")))

(cl-defmethod gnus-modern--update-worker-bootstrap
  ((worker gnus-modern-update-worker-instance))
  "Prepare authentication and Agent support inside WORKER."
  (require 'auth-source-pass)
  (setq auth-source-pass-extra-query-keywords
        (oref worker auth-source-pass-extra-query-keywords))
  (auth-source-pass-enable)
  (setq auth-sources (oref worker auth-sources))
  (require 'gnus-agent)
  (require 'gnus-start)
  (oset worker auth-source-search-function
        (symbol-function 'auth-source-search)))

(cl-defmethod gnus-modern--run ((worker gnus-modern-update-worker-instance))
  "Execute the request stored in WORKER and return its result."
  (gnus-modern--update-worker-protocol-check worker)
  (gnus-modern--update-worker-bootstrap worker)
  (let* ((source (oref worker source))
         (method (oref worker method))
         (groups (oref worker groups))
         (stage (file-name-as-directory
                 (oref worker stage)))
         (gnus-agent-directory stage)
         (gnus-home-directory stage)
         (gnus-directory stage)
         (gnus-startup-file (expand-file-name "newsrc" stage))
         (gnus-select-method method)
         (gnus-secondary-select-methods nil)
         (gnus-agent t)
         (gnus-agent-cache t)
         (gnus-agent-covered-methods (list source))
         (gnus-opened-servers nil)
         (gnus-plugged t)
         (gnus-use-cache nil)
         (gnus-newsrc-alist
          (cons
           (gnus-info-make "dummy.group" 0 nil)
           (mapcar
            (lambda (spec)
              (gnus-info-make
               (plist-get spec :group)
               3
               (plist-get spec :read)
               nil method))
            groups))))
    (cl-letf (((symbol-function 'auth-source-search)
               (lambda (&rest spec)
                 (gnus-modern--auth-source-search worker spec))))
      (setq gnus-active-hashtb (gnus-make-hashtable 50))
      (gnus-make-hashtable-from-newsrc-alist)
      (gnus-modern--update-worker-fetch
       groups method source stage))))

(defun gnus-modern--update-worker-fetch (groups method source stage)
  "Fetch plans for GROUPS through METHOD.
Return the worker result for SOURCE and STAGE."
  (let (plans
        errors
        results
        (completed 0)
        total)
    (pcase-let ((`(,scanned ,scan-errors)
                 (gnus-modern--scan-groups
                  groups method)))
      (setq plans scanned
            errors scan-errors))
    (setq total
          (cl-loop
           for plan in plans
           sum (length (plist-get plan :body-articles))))
    (gnus-modern--update-worker-emit
     "PROGRESS"
     (list :phase 'downloading :done 0 :total total))
    (dolist (plan plans)
      (pcase-let ((`(,fetched ,fetch-errors ,new-completed)
                   (gnus-modern--fetch-group
                    plan completed total)))
        (setq completed new-completed
              errors (nconc errors fetch-errors))
        (push
         (append
          plan
          (list :fetched-bodies fetched))
         results)))
    (list :protocol gnus-modern--update-protocol-version
          :source source
          :method method
          :stage stage
          :groups (nreverse results)
          :errors errors)))

;;;###autoload
(defun gnus-modern-update-worker ()
  "Run one noninteractive Gnus update worker.
Read the update request from the file named by the first remaining
command-line argument and emit the result to standard output."
  (let ((inhibit-message t)
        (message-log-max nil)
        (request-file (car command-line-args-left))
        (worker (make-instance 'gnus-modern-update-worker-instance))
        result)
    (condition-case err
        (progn
          (unless (and (stringp request-file)
                       (file-readable-p request-file))
            (error "Missing or unreadable update request file"))
          (gnus-modern--read-request worker request-file)
          (setq result
                (gnus-modern--run worker)))
      (error
       (setq result
             (list :protocol gnus-modern--update-protocol-version
                   :fatal (error-message-string err)))))
    (gnus-modern--update-worker-emit "RESULT" result)))

;;;; Pure helpers

(defun gnus-modern--update-worker-emit (kind payload)
  "Write a worker message of KIND containing PAYLOAD to standard output."
  (princ (format "GNUS-MODERN-%s %S\n" kind payload)))

(defun gnus-modern--update-worker-decode-header (value)
  "Decode the mail header field VALUE without failing an update."
  (condition-case nil
      (mail-decode-encoded-word-string (or value ""))
    (error (or value ""))))

(defun gnus-modern--update-agent-file (directory method group name)
  "Return the Agent file NAME for GROUP and METHOD below DIRECTORY."
  (let ((gnus-agent-directory (file-name-as-directory directory))
        (gnus-command-method method))
    (gnus-agent-article-name name group)))

(provide 'gnus-modern-update-worker)
;;; gnus-modern-update-worker.el ends here
