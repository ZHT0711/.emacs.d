;; -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t)

(desktop-save-mode 1)
(setq desktop-restore-eager 0
      desktop-restore-reuse-frames nil
      desktop-restore-forces-onscreen nil
      desktop-restore-frames t
      desktop-files-not-to-save "."
      desktop-buffers-not-to-save nil)

(recentf-mode 1)
(setq recentf-max-saved-items 5
      recentf-auto-cleanup 'never
      recentf-exclude '("/tmp/" "/ssh:" "node_modules" ".cache"))
(add-to-list 'recentf-keep '(derived-mode-p . dired-mode))
(add-to-list 'recentf-filename-handlers #'substring-no-properties)
(add-hook 'kill-emacs-hook #'recentf-cleanup -50)

(defconst nn-logo-image-path "~/.emacs.d/logo.png")
(defconst nn-todo-path "~/.emacs.d/todo.md")
(defconst nn-home-buffer "*HOME*")
(defconst nn-home-max-width 64)

(defun nn-create-home-buffer ()
  (let ((buf (get-buffer-create nn-home-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (display-line-numbers-mode -1)
        (setq mode-line-format nil)

        (insert (make-string (/ (window-height) 8) ?\n))
        (nn-insert-logo)

        (text-scale-set -1)

        (nn-insert-group
         "Config"
         '("~/.emacs.d/lisp/"
           "~/.emacs.d/init.el"
           "~/.emacs.d/todo.md"))

        (nn-insert-group
         "Recent Files"
         (seq-take recentf-list recentf-max-saved-items))

        (nn-insert-group
         "Gnus Servers"
         '("nnimap:qq.com"
           "nntp:news.gmane.io")
         #'nn-format-gnus-server-item)

        (nn-insert-group
         "Todo List"
         (nn-parse-todo-item nn-todo-path)
         #'nn-format-todo-item)

        (read-only-mode 1)
        (buffer-disable-undo)
        (use-local-map (nn-home-keymap))
        (setq-local mouse-1-click-follows-link nil)
        (setq-local mouse-highlight nil)
        (setq-local vertical-scroll-bar nil)
        (setq-local text-scale-mode-amount 0)
        (goto-char (point-min))
        (nn-home-next-line)
        (nn-home-next-line)))
    buf))

(defun nn-insert-logo ()
  (when (file-exists-p nn-logo-image-path)
    (let ((padding (/ (window-width) 2)))
      (insert (make-string (max 0 padding) ?\s))
      (insert-image (create-image nn-logo-image-path))
      (insert "\n\n"))))

(defun nn-parse-todo-item (file)
  "解析 `- [text](path)`，返回路径字符串列表。"
  (let ((paths '()))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim (buffer-substring-no-properties
                                    (line-beginning-position)
                                    (line-end-position)))))
            (when (string-match "^- \\[\\(.+?\\)\\](\\(.+\\))" line)
              (push (cons (match-string 1 line) (expand-file-name (match-string 2 line))) paths))
            (forward-line 1)))))
    (nreverse paths)))

(defun nn-format-todo-item (item)
  (let ((text (car item))
        (path (cdr item)))
    (propertize (format " %s" text)
                'keymap (let ((map (make-sparse-keymap)))
                          (define-key map (kbd "RET") (lambda () (interactive) (find-file path)))
                          map)
                'mouse-face 'highlight
                'follow-link t
                'nn-item-data path)))

(defun nn-format-gnus-server-item (server)
  (propertize (format " %s" server)
              'keymap (let ((map (make-sparse-keymap)))
                        (define-key map (kbd "RET") (lambda () (interactive)
                                                      (unless (featurep 'gnus) (gnus))
                                                      (gnus-server-read-server server)))
                        map)
              'mouse-face 'highlight
              'follow-link t
              'nn-item-data server))

(defun nn-get-scale ()
  (expt text-scale-mode-step
        (if (boundp 'text-scale-mode-amount)
            text-scale-mode-amount
          0)))

(defun nn-insert-group (group-name items &optional item-formatter)
  (let* ((formatter (or item-formatter (lambda (x) (format " %s" x))))
         (effective-width (/ (float (window-width)) (nn-get-scale)))
         (center (/ effective-width 2))
         (half-max (/ nn-home-max-width 4))
         (padding (round (- center half-max))))
    (setq padding (max 0 padding))
    (let ((title-pos (point)))
      (insert (make-string padding ?\s) (nn-truncate group-name) "\n")
      (put-text-property title-pos (point) 'nn-group-header t)
      (put-text-property title-pos (point) 'nn-group-name (intern group-name))
      (put-text-property title-pos (point) 'nn-group-open t))
    (dolist (item items)
      (let ((item-pos (point))
            (line (funcall formatter item)))
        (insert (make-string padding ?\s) (nn-truncate line) "\n")
        (put-text-property item-pos (point) 'nn-group-member (intern group-name))
        (put-text-property item-pos (point) 'nn-item-data item))))
  (insert "\n"))

(defun nn-truncate (str)
  (if (<= (length str) nn-home-max-width)
      str (concat (substring str 0 (- nn-home-max-width 3)) "...")))

(defun nn-home-return-action ()
  (interactive)
  (let* ((header-p (get-text-property (point) 'nn-group-header))
         (item-data (get-text-property (point) 'nn-item-data)))
    (cond (header-p (nn-home-toggle-group))
          (item-data (find-file item-data)))))

(defun nn-home-toggle-group ()
  (interactive)
  (let ((group-name (get-text-property (point) 'nn-group-name))
        (is-open (get-text-property (point) 'nn-group-open)))
    (if is-open (nn-home-collapse-group group-name)
      (nn-home-expand-group group-name))))

(defun nn-home-collapse-group (group-name)
  (let ((inhibit-read-only t))
    (save-excursion
      ;; 隐藏所有属于该组的成员行
      (let ((pos (point)))
        (goto-char (point-min))
        (while (< (point) (point-max))
          (if (eq (get-text-property (point) 'nn-group-member) group-name)
              (let ((line-start (line-beginning-position))
                    (line-end (line-end-position)))
                (put-text-property line-start (+ line-end 1) 'invisible t)))
          (forward-line 1))
        (goto-char pos)))
    ;; 更新标题的打开状态
    (put-text-property (line-beginning-position) (line-end-position) 'nn-group-open nil)))

(defun nn-home-expand-group (group-name)
  (let ((inhibit-read-only t))
    (save-excursion
      ;; 显示所有属于该组的成员行
      (let ((pos (point)))
        (goto-char (point-min))
        (while (< (point) (point-max))
          (if (eq (get-text-property (point) 'nn-group-member) group-name)
              (let ((line-start (line-beginning-position))
                    (line-end (line-end-position)))
                (put-text-property line-start (+ line-end 1) 'invisible nil)))
          (forward-line 1))
        (goto-char pos)))
    ;; 更新标题的打开状态
    (put-text-property (line-beginning-position) (line-end-position) 'nn-group-open t)))

(defun nn-home-next-line ()
  (interactive)
  (forward-line 1)
  (skip-chars-forward " \t\n"))

(defun nn-home-previous-line ()
  (interactive)
  (let ((prev-pos (point)))
    (forward-line -1)
    (if (looking-at-p "^\\s-*$")
        (forward-line -1))
    (skip-chars-forward " \t\n")
    (if (= (point) prev-pos)
        (goto-char (point-min)))))

(defun nn-home-quit ()
  (interactive)
  (save-buffers-kill-terminal))

(defun nn-home-refresh ()
  (interactive)
  (let ((buf (current-buffer)))
    (when (eq buf (get-buffer nn-home-buffer))
      (let ((pos (point)))
        (nn-create-home-buffer)
        (switch-to-buffer nn-home-buffer)
        (goto-char (min pos (point-max)))))))

(defun nn-home-keymap ()
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'nn-home-return-action)
    (define-key map (kbd "o") 'nn-home-return-action)
    (define-key map (kbd "<down>") 'nn-home-next-line)
    (define-key map (kbd "<up>") 'nn-home-previous-line)
    (define-key map (kbd "n") 'nn-home-next-line)
    (define-key map (kbd "p") 'nn-home-previous-line)
    (define-key map (kbd "q") 'nn-home-quit)
    (define-key map (kbd "g") 'nn-home-refresh)
    map))

(defun nn-show-home-workspace ()
  (interactive)
  (let ((buf (get-buffer nn-home-buffer)))
    (if (and buf (eq (current-buffer) buf))
        (kill-buffer buf)
      (switch-to-buffer (nn-create-home-buffer)))))

(add-hook 'window-setup-hook
          (lambda ()
            (when (and (not (cdr command-line-args))
                       (not (buffer-file-name)))
              (nn-show-home-workspace))))

(keymap-global-set "C-<f1>" #'nn-show-home-workspace)

(provide 'init-start)
