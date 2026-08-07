;;; nn-markdown-preview.el --- Markdown preview via GitHub API -*- lexical-binding: t; -*-
;;; Commentary:
;; Minor mode for live markdown preview.  `C-c C-p' toggles.
;;; Code:
(require 'shr)
(require 'json)

(defvar nn-markdown-preview--buffer nil)
(defvar nn-markdown-preview--base-dir nil)

(defun nn-markdown-preview--fetch ()
  (let* ((json (json-serialize `(:text ,(buffer-string))))
         (buf (generate-new-buffer " *nn-md-preview*")))
    (unwind-protect
        (with-temp-buffer
          (insert json)
          (call-process-region (point-min) (point-max) "curl" t buf nil
                               "-s" "-X" "POST"
                               "https://api.github.com/markdown"
                               "-H" "Content-Type: application/json"
                               "-H" "Accept: application/vnd.github.raw+json"
                               "-d" "@-")
          (with-current-buffer buf
            (let ((html (buffer-string)))
              (unless (string-empty-p (string-trim html)) html))))
      (kill-buffer buf))))

(defun nn-markdown-preview--ensure-buffer ()
  (or (and nn-markdown-preview--buffer (buffer-live-p nn-markdown-preview--buffer)
           nn-markdown-preview--buffer)
      (with-current-buffer (generate-new-buffer "*nn-markdown-preview*")
        (special-mode) (setq-local mode-line-format nil)
        (setq nn-markdown-preview--buffer (current-buffer)))))

(defun nn-markdown-preview--render-into (buffer html)
  (setq html (concat "<head><base href=\"file:///"
                     (replace-regexp-in-string "\\\\" "/"
                                               (or nn-markdown-preview--base-dir default-directory))
                     "\"></head>" html))
  (with-current-buffer buffer
    (let ((inhibit-read-only t)
          (shr-width (if-let* ((w (get-buffer-window buffer))) (window-body-width w) shr-width)))
      (erase-buffer)
      (shr-insert-document (with-temp-buffer (insert html) (libxml-parse-html-region (point-min) (point-max))))
      (goto-char (point-min)))))

(defun nn-markdown-preview--refresh ()
  (when (and nn-markdown-preview--buffer
             (bound-and-true-p nn-markdown-preview-mode))
    (condition-case _err
        (when-let* ((html (nn-markdown-preview--fetch)))
          (nn-markdown-preview--render-into
           (nn-markdown-preview--ensure-buffer) html))
      (error nil))))

;;;###autoload
(defun nn-markdown-preview ()
  (interactive)
  (if (and nn-markdown-preview-mode
           nn-markdown-preview--buffer
           (buffer-live-p nn-markdown-preview--buffer))
      (nn-markdown-preview-mode -1)
    (let ((html (nn-markdown-preview--fetch)))
      (unless html (user-error "Render failed"))
      (setq nn-markdown-preview--base-dir
            (when-let* ((f (buffer-file-name))) (file-name-directory f)))
      (nn-markdown-preview-mode 1)
      (let ((buf (nn-markdown-preview--ensure-buffer)))
        (display-buffer buf
                        '((display-buffer-reuse-window display-buffer-in-direction)
                          (direction . right)))
        (with-current-buffer buf
          (add-hook 'kill-buffer-hook
                    (lambda ()
                      (setq nn-markdown-preview--buffer nil
                            nn-markdown-preview--base-dir nil))
                    nil t))
        (nn-markdown-preview--render-into buf html))
      (add-hook 'after-save-hook #'nn-markdown-preview--refresh nil t)
      (message "Preview started"))))

;;;###autoload
(define-minor-mode nn-markdown-preview-mode
  "Minor mode for live markdown preview."
  :lighter " MD-Preview"
  :keymap (let ((map (make-sparse-keymap)))
            (keymap-set map "w" #'nn-markdown-preview-mode)
            map)
  (if nn-markdown-preview-mode
      (unless (derived-mode-p 'markdown-mode)
        (setq nn-markdown-preview-mode nil)
        (user-error "Not in markdown-mode"))
    (remove-hook 'after-save-hook #'nn-markdown-preview--refresh t)
    (when-let* ((b nn-markdown-preview--buffer)) (kill-buffer b))
    (setq nn-markdown-preview--buffer nil
          nn-markdown-preview--base-dir nil)))

(provide 'nn-markdown-preview)
;;; nn-markdown-preview.el ends here
