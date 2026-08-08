;;; gnus-modern-summary-navigate.el --- Summary navigation commands  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bingshan Chang

;; Author: Bingshan Chang <chang@bingshan.org>
;; Keywords: extensions
;; Version: 0.1.0

;; This file is part of gnus-modern.

;;; Commentary:

;; Visible-article navigation for the custom Summary renderer
;; (`gnus-modern-summary-next' / `gnus-modern-summary-previous'),
;; Agent download commands, and the local today / subthread context
;; commands that build `*Gnus Thread Context*' buffers from locally
;; indexed articles without contacting any news server.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'gnus)
(require 'gnus-modern-core)
(require 'gnus-modern-custom)
(require 'gnus-modern-summary-format)
(require 'gnus-modern-update)

(declare-function gnus-data-number "gnus-sum" (data))
(declare-function gnus-summary-article-number "gnus-sum" ())
(declare-function gnus-summary-goto-subject
                  "gnus-sum" (article &optional force silent))
(declare-function gnus-summary-insert-old-articles "gnus-sum" (&optional all))
(declare-function gnus-summary-insert-new-articles "gnus-sum" ())
(declare-function gnus-summary-recenter "gnus-sum" ())
(declare-function gnus-summary-select-article
                  "gnus-sum"
                  (&optional all-headers force pseudo article))
(declare-function gnus-summary-update-download-mark "gnus-sum" (article))
(declare-function gnus-article-prepare-display "gnus-art" ())
(declare-function gnus-agent-fetch-articles "gnus-agent" (group articles))
(declare-function gnus-agent-request-article "gnus-agent" (article group))
(declare-function gnus-agent-method-p "gnus" (method-or-server))
(declare-function gnus-sorted-ndifference "gnus-range" (list1 list2))

(defvar gnus-agent)
(defvar gnus-agent-cache)
(defvar gnus-agent-directory)
(defvar gnus-article-buffer)
(defvar gnus-article-internal-prepare-hook)
(defvar gnus-auto-extend-newsgroup)
(defvar gnus-command-method)
(defvar gnus-current-article)
(defvar gnus-level-subscribed)
(defvar gnus-newsgroup-data)
(defvar gnus-newsgroup-name)
(defvar gnus-newsgroup-undownloaded)
(defvar gnus-newsrc-alist)
(defvar gnus-summary-buffer)
(defvar gnus-tmp-internal-hook)
(defvar gnus-topic-alist)
(defvar gnus-topic-topology)

(defvar gnus-modern--summary-navigation-from-article nil
  "Non-nil while an Article buffer delegates a Summary command.")

;;; Visible-article navigation

(defun gnus-modern--article-read-summary-keys-advice
    (function &rest arguments)
  "Call FUNCTION with ARGUMENTS as an Article-originated command."
  (let ((gnus-modern--summary-navigation-from-article t))
    (apply function arguments)))

(defun gnus-modern--summary-sync-article-navigation ()
  "Start Article-originated navigation at the displayed article."
  (when (and gnus-modern--summary-navigation-from-article
             gnus-current-article
             (gnus-summary-goto-subject
              gnus-current-article nil t))
    (gnus-modern--summary-position-point)))

(defun gnus-modern--summary-find-visible-article (direction)
  "Move to the next visible real article in DIRECTION.
DIRECTION is 1 for following lines and -1 for preceding lines.
Return the article number, or nil at the buffer boundary."
  (let (article)
    (while (and (not article)
                (zerop (forward-line direction)))
      (let ((number
             (get-text-property
              (line-beginning-position) 'gnus-number)))
        (when (and (integerp number)
                   (> number 0)
                   (not (invisible-p (line-beginning-position))))
          (setq article number))))
    (when article
      (gnus-modern--summary-position-point))
    article))

(defun gnus-modern--summary-extend-at-boundary (direction)
  "Extend the Summary at its boundary in DIRECTION."
  (when gnus-auto-extend-newsgroup
    (if (> direction 0)
        (and (> gnus-modern-summary-auto-extend-count 0)
             (gnus-modern--summary-extend-old-articles))
      (gnus-modern--summary-extend-new-articles))))

(defun gnus-modern--summary-follow-point ()
  "Display the article at point when its Article buffer is visible."
  (when (and gnus-modern-summary-follow-visible-article
             (not gnus-modern--summary-navigation-from-article)
             gnus-article-buffer
             (get-buffer-window gnus-article-buffer t))
    (gnus-summary-select-article)))

(defun gnus-modern--summary-move-visible-articles (count direction)
  "Move COUNT visible articles in DIRECTION.
Return the number of requested steps that could not be completed."
  (let* ((direction
          (* direction (if (< count 0) -1 1)))
         (remaining (abs count))
         (moved 0))
    (while
        (and
         (> remaining 0)
         (or
          (gnus-modern--summary-find-visible-article direction)
          (let (article)
            (while (and (not article)
                        (gnus-modern--summary-extend-at-boundary
                         direction))
              (setq article
                    (gnus-modern--summary-find-visible-article
                     direction)))
            article)))
      (setq remaining (1- remaining)))
    (setq moved (- (abs count) remaining))
    (when (> moved 0)
      (gnus-summary-recenter)
      (gnus-modern--summary-position-point)
      (gnus-modern--summary-follow-point)
      (gnus-modern--summary-refresh-hl-line))
    (when (> remaining 0)
      (gnus-message 7 "No more articles"))
    remaining))

(defun gnus-modern--summary-extend-old-articles ()
  "Insert a batch of older articles and preserve the current article.
Return non-nil when the Summary gained at least one article."
  (let ((article (gnus-summary-article-number))
        (count (length gnus-newsgroup-data)))
    (gnus-summary-insert-old-articles
     gnus-modern-summary-auto-extend-count)
    (when article
      (gnus-summary-goto-subject article nil t))
    (> (length gnus-newsgroup-data) count)))

(defun gnus-modern--summary-extend-new-articles ()
  "Insert newly available articles and preserve the current article.
Return non-nil when the Summary gained at least one article."
  (let ((article (gnus-summary-article-number))
        (count (length gnus-newsgroup-data)))
    (gnus-summary-insert-new-articles)
    (when article
      (gnus-summary-goto-subject article nil t))
    (> (length gnus-newsgroup-data) count)))

;;;###autoload
(defun gnus-modern-summary-next (&optional count)
  "Move to the COUNTth next concrete Summary article."
  (interactive "p")
  (unless (gnus-modern--summary-article-buffer-p)
    (user-error "This command requires a Gnus Summary buffer"))
  (gnus-modern--summary-sync-article-navigation)
  (gnus-modern--summary-move-visible-articles (or count 1) 1))

;;;###autoload
(defun gnus-modern-summary-previous (&optional count)
  "Move to the COUNTth previous concrete Summary article."
  (interactive "p")
  (unless (gnus-modern--summary-article-buffer-p)
    (user-error "This command requires a Gnus Summary buffer"))
  (gnus-modern--summary-sync-article-navigation)
  (gnus-modern--summary-move-visible-articles (or count 1) -1))

;;; Agent download

(defun gnus-modern--summary-agent-article-available-p (group article)
  "Return non-nil when ARTICLE from GROUP is stored in the Agent."
  (with-temp-buffer
    (let ((gnus-agent-cache t))
      (gnus-agent-request-article article group))))

(defun gnus-modern--summary-download-articles (group articles)
  "Ensure that GROUP ARTICLES are stored in the Gnus Agent."
  (require 'gnus-agent)
  (unless gnus-agent
    (user-error "Gnus Agent is not enabled"))
  (let* ((articles (sort (copy-sequence articles) #'<))
         (missing
          (cl-remove-if
           (lambda (article)
             (gnus-modern--summary-agent-article-available-p
              group article))
           articles))
         fetch-error)
    (when missing
      (let ((method (gnus-find-method-for-group group)))
        (unless (gnus-agent-method-p method)
          (user-error "The current Gnus method is not agentized"))
        (condition-case error-data
            (let ((gnus-command-method method))
              (gnus-agent-fetch-articles
               group (copy-sequence missing)))
          (error
           (setq fetch-error (error-message-string error-data))))))
    (let ((failed
           (cl-remove-if
            (lambda (article)
              (gnus-modern--summary-agent-article-available-p
               group article))
            articles)))
      (when failed
        (user-error
         "Failed to download Gnus articles %s%s"
         (mapconcat #'number-to-string failed ", ")
         (if fetch-error (format ": %s" fetch-error) ""))))
    (setq gnus-newsgroup-undownloaded
          (gnus-sorted-ndifference
           gnus-newsgroup-undownloaded articles))
    (save-excursion
      (dolist (article articles)
        (when (gnus-summary-goto-subject article nil t)
          (gnus-summary-update-download-mark article))))))

(defun gnus-modern--summary-render-agent-article
    (summary-buffer group article)
  "Render ARTICLE from GROUP using SUMMARY-BUFFER settings."
  (require 'gnus-art)
  (with-temp-buffer
    (let ((gnus-agent-cache t)
          (gnus-article-buffer (current-buffer))
          (gnus-summary-buffer summary-buffer)
          (gnus-tmp-internal-hook
           gnus-article-internal-prepare-hook))
      (unless (gnus-agent-request-article article group)
        (error "Gnus article %d is absent from the Agent" article))
      (gnus-article-prepare-display)
      (gnus-modern--decode-raw-utf-8
       (string-trim-right
        (buffer-substring-no-properties
         (point-min) (point-max)))))))

(defun gnus-modern--summary-build-thread-context
    (summary-buffer group articles)
  "Build a thread context for GROUP ARTICLES from SUMMARY-BUFFER."
  (let ((texts
         (mapcar
          (lambda (article)
            (gnus-modern--summary-render-agent-article
             summary-buffer group article))
          articles))
        (count (length articles)))
    (with-current-buffer
        (get-buffer-create gnus-modern-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert "# Thread Context\n\n"
              (format "Source: Gnus group `%s`\n\n" group)
              (format "Articles: %d\n" count))
      (cl-loop for text in texts
               for index from 1
               do (insert (format "\n## Article %d of %d\n\n"
                                  index count)
                          text "\n"))
      (set-buffer-modified-p nil)
      (current-buffer))))

;;; Today context

(defun gnus-modern--today-overview-records
    (file group method start end)
  "Return today's records from overview FILE for GROUP and METHOD.
START and END are epoch seconds bounding the local calendar day."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (let (records)
        (while (not (eobp))
          (let* ((line
                  (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position)))
                 (fields (split-string line "\t" nil))
                 (article (and (car fields)
                               (string-to-number (car fields))))
                 (date (nth 3 fields))
                 (timestamp
                  (and date
                       (condition-case nil
                           (float-time (date-to-time date))
                         (error nil)))))
            (when (and (>= (length fields) 6)
                       (> article 0)
                       timestamp
                       (<= start timestamp)
                       (< timestamp end))
              (push
               (list :group group
                     :method method
                     :article article
                     :subject
                     (gnus-modern--update-worker-decode-header
                      (nth 1 fields))
                     :from
                     (gnus-modern--update-worker-decode-header
                      (nth 2 fields))
                     :date date
                     :timestamp timestamp
                     :message-id (nth 4 fields)
                     :references (nth 5 fields))
               records)))
          (forward-line 1))
        (nreverse records)))))

(defun gnus-modern--today-records (&optional groups)
  "Return today's locally indexed articles from Gnus GROUPS.
When GROUPS is nil, use every subscribed group."
  (pcase-let ((`(,start . ,end) (gnus-modern--today-time-bounds)))
    (let ((groups
           (or groups
               (cl-loop
                for info in (cdr gnus-newsrc-alist)
                when (<= (gnus-info-level info) gnus-level-subscribed)
                collect (gnus-info-group info))))
          records)
      (dolist (group (delete-dups (copy-sequence groups)))
        (let ((method (gnus-find-method-for-group group)))
          (when (gnus-agent-method-p method)
            (setq records
                  (nconc
                   records
                   (gnus-modern--today-overview-records
                    (gnus-modern--update-agent-file
                     gnus-agent-directory method group ".overview")
                    group method start end))))))
      (sort records
            (lambda (left right)
              (< (plist-get left :timestamp)
                 (plist-get right :timestamp)))))))

(defun gnus-modern--topic-subtree-groups (topic)
  "Return every group assigned to TOPIC or one of its descendants."
  (cl-labels
      ((find-node
         (node)
         (if (equal topic (car (car node)))
             node
           (cl-some #'find-node (cdr node))))
       (collect-groups
         (node)
         (nconc
          (copy-sequence
           (cdr (assoc (car (car node)) gnus-topic-alist)))
          (cl-mapcan #'collect-groups (cdr node)))))
    (let ((node
           (and gnus-topic-topology
                (find-node gnus-topic-topology))))
      (delete-dups
       (if node
           (collect-groups node)
         (copy-sequence (cdr (assoc topic gnus-topic-alist))))))))

(defun gnus-modern--today-context-scope ()
  "Return the context scope at point as (DESCRIPTION . GROUPS)."
  (cond
   ((derived-mode-p 'gnus-summary-mode)
    (unless (and (stringp gnus-newsgroup-name)
                 (not (string-empty-p gnus-newsgroup-name)))
      (user-error "The current Summary buffer has no Gnus group"))
    (cons (format "Gnus Summary group `%s`" gnus-newsgroup-name)
          (list gnus-newsgroup-name)))
   ((derived-mode-p 'gnus-group-mode)
    (let* ((position (line-beginning-position))
           (group (get-text-property position 'gnus-group))
           (topic (get-text-property position 'gnus-topic))
           (level (get-text-property position 'gnus-topic-level)))
      (cond
       (group
        (cons (format "Gnus group `%s`" group) (list group)))
       (topic
        (cons
         (if (and (numberp level) (zerop level))
             (format "Gnus root `%s`" topic)
           (format "Gnus topic `%s`" topic))
         (gnus-modern--topic-subtree-groups topic)))
       (t
        (user-error "Point is not on a Gnus group or topic")))))))

(defun gnus-modern--context-thread-key (record)
  "Return a stable thread key for Gnus overview RECORD."
  (or (car (split-string (or (plist-get record :references) "")))
      (let ((message-id (plist-get record :message-id)))
        (and (not (string-empty-p (or message-id "")))
             message-id))
      (downcase
       (gnus-modern--message-base-subject (plist-get record :subject)))))

(defun gnus-modern--records-by-thread (records)
  "Group chronological Gnus RECORDS by thread in first-article order."
  (gnus-modern--group-by records #'gnus-modern--context-thread-key))

(defun gnus-modern--context-article-fallback (record &optional error-data)
  "Return metadata for unavailable article RECORD.
When ERROR-DATA is non-nil, include its local rendering error."
  (format
   (concat "From: %s\nSubject: %s\nDate: %s\n"
           "Message-ID: %s\nNewsgroup: %s\nArticle: %d\n\n%s")
   (or (plist-get record :from) "[unknown]")
   (or (plist-get record :subject) "[no subject]")
   (or (plist-get record :date) "[unknown]")
   (or (plist-get record :message-id) "[none]")
   (plist-get record :group)
   (plist-get record :article)
   (if error-data
       (format "[Article body could not be rendered locally: %s]"
               (error-message-string error-data))
     "[Article body was not cached locally.]")))

(defun gnus-modern--render-context-record (source record)
  "Render Gnus overview RECORD using SOURCE buffer settings."
  (condition-case error-data
      (let ((gnus-command-method (plist-get record :method))
            (group (plist-get record :group))
            (article (plist-get record :article)))
        (if (gnus-modern--summary-agent-article-available-p group article)
            (gnus-modern--summary-render-agent-article
             source group article)
          (gnus-modern--context-article-fallback record)))
    (error
     (gnus-modern--context-article-fallback record error-data))))

(defun gnus-modern--build-today-context (source records &optional description)
  "Build and return a Gnus context from today's RECORDS using SOURCE.
DESCRIPTION identifies the selected Gnus scope."
  (let* ((threads (gnus-modern--records-by-thread records))
         (preamble
          (gnus-modern--today-context-preamble
           description threads records))
         (sections (gnus-modern--today-context-sections threads)))
    (gnus-modern--today-context-buffer source preamble sections)))

(defun gnus-modern--today-context-preamble (description threads records)
  "Return the preamble text for today's context."
  (concat
   "# Today's Gnus Context\n\n"
   (format
    "Source: %s\n\n"
    (or description
        "All subscribed groups in the local Gnus Agent"))
   (format "Threads: %d\n" (length threads))
   (format "Articles: %d\n" (length records))))

(defun gnus-modern--today-context-sections (threads)
  "Return heading and article sections for THREADS."
  (cl-loop
   for thread in threads
   for thread-index from 1
   for groups = (delete-dups
                 (mapcar
                  (lambda (record)
                    (plist-get record :group))
                  thread))
   collect
   (cons
    (concat
     (format "\n## Thread %d of %d: %s\n\n"
             thread-index (length threads)
             (gnus-modern--message-base-subject
              (plist-get (car thread) :subject)))
     (format "Newsgroups: %s\n"
             (mapconcat #'identity groups ", ")))
    (cl-loop
     for record in thread
     for article-index from 1
     collect
     (cons
      (format "\n### Article %d of %d\n\n"
              article-index (length thread))
      record)))))

(defun gnus-modern--today-context-buffer (source preamble sections)
  "Build the context buffer from SOURCE, PREAMBLE, and SECTIONS."
  (let* ((article-count
          (cl-loop for (_heading . articles) in sections
                   sum (length articles)))
         (fixed-length
          (gnus-modern--today-context-fixed-length
           preamble sections))
         (body-budget
          (if (zerop article-count)
              0
            (/ (max 0
                    (- gnus-modern-today-context-maximum-length
                       fixed-length))
               article-count))))
    (when (> fixed-length gnus-modern-today-context-maximum-length)
      (user-error
       "Gnus today context metadata needs %d characters; budget is %d"
       fixed-length gnus-modern-today-context-maximum-length))
    (with-current-buffer
        (get-buffer-create gnus-modern-context-buffer-name)
      (fundamental-mode)
      (erase-buffer)
      (insert preamble)
      (dolist (section sections)
        (insert (car section))
        (dolist (article (cdr section))
          (insert
           (car article)
           (gnus-modern--today-context-render
            source (cdr article) body-budget)
           "\n")))
      (set-buffer-modified-p nil)
      (current-buffer))))

(defun gnus-modern--today-context-fixed-length (preamble sections)
  "Return the metadata length of PREAMBLE and SECTIONS."
  (+ (length preamble)
     (cl-loop
      for (heading . articles) in sections
      sum
      (+ (length heading)
         (cl-loop
          for article in articles
          sum (1+ (length (car article))))))))

(defun gnus-modern--today-context-render (source record body-budget)
  "Return RECORD rendered with SOURCE, truncated to BODY-BUDGET."
  (let* ((truncation
          "\n\n[Article body truncated to fit context budget.]")
         (rendered
          (gnus-modern--render-context-record source record)))
    (if (> (length rendered) body-budget)
        (concat
         (substring
          rendered 0
          (max 0 (- body-budget (length truncation))))
         (substring
          truncation 0 (min body-budget (length truncation))))
      rendered)))

;;;###autoload
(defun gnus-modern-summary-prepare-subthread-context ()
  "Prepare the article at point and its replies as thread context.
Download every article to the Gnus Agent before replacing
the buffer named by `gnus-modern-context-buffer-name'.  Keep that
buffer hidden by default, select the current Summary row, and run
`gnus-modern-summary-thread-context-hook'."
  (interactive)
  (unless (derived-mode-p 'gnus-summary-mode)
    (user-error "This command requires a Gnus Summary buffer"))
  (let* ((summary-buffer (current-buffer))
         (article (gnus-summary-article-number))
         (thread
          (and article
               (gnus-modern--summary-thread-for-article article)))
         (anchor
          (and thread
               (cl-find article thread :key #'gnus-data-number)))
         (subthread
          (and anchor
               (cons anchor
                     (gnus-modern--summary-descendants
                      article thread))))
         (articles
          (mapcar #'gnus-data-number subthread))
         (group gnus-newsgroup-name))
    (unless anchor
      (user-error "No Gnus article thread at point"))
    (unless (cl-every
             (lambda (number)
               (and (integerp number) (> number 0)))
             articles)
      (user-error
       "The subthread contains unavailable sparse articles"))
    (gnus-modern--summary-download-articles group articles)
    (let ((context
           (gnus-modern--summary-build-thread-context
            summary-buffer group articles)))
      (gnus-summary-goto-subject article nil t)
      (run-hooks 'gnus-modern-summary-thread-context-hook)
      (if gnus-modern-summary-display-thread-context
          (progn
            (pop-to-buffer context)
            (goto-char (point-min))
            (push-mark (point-max) nil t))
        (goto-char (line-beginning-position))
        (push-mark (line-end-position) nil t)
        (message "Prepared %d Gnus articles in %s"
                 (length articles)
                 gnus-modern-context-buffer-name)))))

;;;###autoload
(defun gnus-modern-prepare-today-context ()
  "Prepare today's local articles from a Gnus Group or Summary buffer.
In a Group buffer, use the group at point or every group below the
topic at point; the root topic includes the complete topic tree.  In
a Summary buffer, use only the current group.
Group articles by thread and order each thread chronologically.
Read only Agent overview and body data without contacting any news
server."
  (interactive)
  (unless (derived-mode-p 'gnus-group-mode 'gnus-summary-mode)
    (user-error "This command requires a Gnus Group or Summary buffer"))
  (require 'gnus-agent)
  (unless gnus-agent
    (user-error "Gnus Agent is not enabled"))
  (let* ((source (current-buffer))
         (scope (gnus-modern--today-context-scope))
         (description (car scope))
         (groups (cdr scope)))
    (unless groups
      (user-error "No Gnus groups belong to %s" description))
    (let ((records (gnus-modern--today-records groups)))
      (unless records
        (user-error "No locally indexed Gnus articles from today in %s"
                    description))
      (gnus-modern--build-today-context source records description)
      (run-hooks 'gnus-modern-summary-thread-context-hook)
      (message "Prepared %d Gnus articles from today in %s (%s)"
               (length records) gnus-modern-context-buffer-name
               description))))

(provide 'gnus-modern-summary-navigate)
;;; gnus-modern-summary-navigate.el ends here
