;;; -*- lexical-binding: t -*-
(use-package eldoc
  :ensure nil
  :bind (("M-<return>" . eldoc-print-current-symbol-info)
         ("C-c h ." . my-eldoc-copy))
  :custom
  (eldoc-idle-delay 0.5)
  (eldoc-idle-delay-visible-only t)
  (eldoc-echo-area-use-multiline-p nil)
  (eldoc-documentation-strategy 'eldoc-documentation-enthusiast)
  :config
  (defun my-eldoc-copy ()
    (interactive)
    (when-let* ((buf (eldoc-doc-buffer)))
      (kill-new (with-current-buffer buf (buffer-string)))
      (message "Copied eldoc to kill ring"))))

(use-package minibuffer
  :ensure nil
  :hook (minibuffer-setup-hook . cursor-intangible-mode)
  :custom
  (echo-keystrokes 0.02)
  (minibuffer-prompt-properties
   '(read-only t intangible t cursor-intangible t face minibuffer-prompt))
  (completion-show-inline-help nil)
  (completion-auto-help 'always)
  (completion-cycle-threshold 5)
  (completion-flex-nospace t)
  (completion-ignore-case t)
  (completion-lazy-hilit t)
  (completion-lazy-hilit-fn #'flex-completion-lazy-hilit)
  (completions-max-height 10)
  (completions-detailed t)
  (completions-format 'one-column))

(use-package dired
  :ensure nil
  :commands dired-jump
  :bind (:map dired-mode-map
              ("-" . dired-create-empty-file)
              ("C-c C-e" . wdired-change-to-wdired-mode))
  :hook (dired-mode . my-dired-vc-ignores)
  :custom
  (dired-dwim-target t)
  (dired-mouse-drag-files t)
  (dired-auto-revert-buffer #'dired-buffer-stale-p)
  (dired-recursive-deletes 'top)
  (dired-recursive-copies 'always)
  (dired-create-destination-dirs 'always)
  (dired-no-confirm '(move copy delete))
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-listing-switches "-alh --group-directories-first")
  :config
  (put 'dired-find-alternate-file 'disabled nil)

  (define-advice dired-buffer-stale-p (:before-while (&rest args) my-dired--no-revert-in-virtual-buffers-a)
    "Don't auto-revert in dired-virtual buffers (see `dired-virtual-revert')."
    (not (eq revert-buffer-function #'dired-virtual-revert)))

  ;; 实现git忽略着色
  (defun my-get-vc-ignore-list ()
    (when-let* ((backend (and (vc-root-dir)
                              (vc-responsible-backend default-directory)))
                (ignores (vc-call-backend backend 'ignore-completion-table default-directory)))
      ignores))

  (defun my-get-dired-vc-font-lock-keywords ()
    (when-let* ((ignores (my-get-vc-ignore-list)))
      (mapcar (lambda (item)
                `(,dired-move-to-filename-regexp
                  (,(regexp-quote item)
                   (dired-move-to-filename) nil (0 'dired-ignored t))))
              ignores)))

  (defun my-dired-vc-ignores ()
    (when-let* ((keywords (my-get-dired-vc-font-lock-keywords)))
      (font-lock-add-keywords nil keywords 'add-to-end))))

(use-package dired-aux
  :ensure nil
  :custom
  (dired-vc-rename-file t)
  (dired-do-revert-buffer t)
  ;; 大写Z用的命令
  (dired-compress-file-alist
   '(("\\.7z\\'" . "7z a -r %o %i")
     ("\\.zip\\'" . "7z a -r %o  %i"))
   ;; 小写z用的命令，统一用7z，解压的话是根据文件后辍调用shell，同步用!，异步用&
   (dired-compress-files-alist
    '(("\\.7z\\'" . "7z a -r %o %i")
      ("\\.zip\\'" . "7z a -r %o  %i")))
   (dired-compress-directory-default-suffix ".7z")
   (dired-compress-file-default-suffix ".7z")))

(use-package dired-x
  :ensure nil
  :custom
  (dired-omit-files
   (concat "\\`[.]\\|[#~]\\'"
           (cond
            ((eq system-type 'windows-nt)
             "\\|^desktop\\.ini$\\|^Thumbs\\.db$\\|^System Volume Information$\\|^\\$RECYCLE\\.BIN$")
            ((eq system-type 'darwin)
             "\\|^\\.DS_Store$\\|^\\.localized$\\|^\\._")
            (t ""))))
  :config
  (put 'dired-find-alternate-file 'disabled nil)
  (let ((cmd (cond ((eq system-type 'darwin) "open")
                   ((eq system-type 'gnu/linux) "xdg-open")
                   ((eq system-type 'windows-nt) "start")
                   (t ""))))
    (setq dired-guess-shell-alist-user
          `(("\\.pdf\\'" ,cmd)
            ("\\.docx\\'" ,cmd)
            ("\\.\\(?:djvu\\|eps\\)\\'" ,cmd)
            ("\\.\\(?:jpg\\|jpeg\\|png\\|gif\\|xpm\\)\\'" ,cmd)
            ("\\.\\(?:xcf\\)\\'" ,cmd)
            ("\\.csv\\'" ,cmd)
            ("\\.tex\\'" ,cmd)
            ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
            ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
            ("\\.html?\\'" ,cmd)
            ("\\.md\\'" ,cmd)))))

(use-package image-dired
  :ensure nil
  :custom (image-dired-thumb-size 150)
  :config
  (add-to-list
   'display-buffer-alist
   '("^\\*image-dired"
     (display-buffer-in-side-window)
     (side . bottom)
     (slot . 20)
     (window-width . 0.8))))

(use-package speedbar
  :ensure nil
  :bind
  (("C-|" . nn-speedbar-toggle)
   :map speedbar-mode-map
   ("q" . nn-speedbar-close))
  :custom
  (speedbar-use-images nil)
  (speedbar-use-imenu-flag nil)
  (speedbar-use-tool-tips-flag nil)
  (speedbar-hide-button-brackets-flag t)
  (speedbar-mode-specific-contents-flag nil)
  (speedbar-mode-functions-list nil)
  (speedbar-dynamic-tags-function-list nil)
  (speedbar-special-mode-expansion-list nil)
  (speedbar-show-unknown-files t)
  (speedbar-smart-directory-expand-flag t)
  (speedbar-verbosity-level 0)
  (speedbar-directory-unshown-regexp "^\\(\\.\\.*$\\)")
  :config
  (defvar nn-speedbar-width 30)
  (defvar nn-speedbar-split-style 'right)

  (when (>= emacs-major-version 31)
    (setq speedbar-prefer-window t
          speedbar--window-width nn-speedbar-width
          speedbar-window-side nn-speedbar-split-style)

    (defun nn-speedbar-toggle ()
      "Toggle speedbar window (Emacs 31+ native version)."
      (interactive)
      (speedbar))

    (defun nn-speedbar-close()
      (interactive)
      (delete-window)))

  (when (< emacs-major-version 31)
    (defvar nn-speedbar-window nil)

    (defun nn-speedbar-toggle ()
      "Toggle speedbar window (Custom implementation for Emacs 30 and earlier)."
      (interactive)
      (if (nn-speedbar-exist-p)
          (nn-speedbar-close)
        (nn-speedbar-open)))

    (defun nn-speedbar-exist-p ()
      "Check if speedbar window exists."
      (and nn-speedbar-window
           (window-live-p nn-speedbar-window)
           (buffer-live-p (window-buffer nn-speedbar-window))))

    (defun nn-speedbar-open ()
      "Open speedbar on left side."
      (let ((current-window (selected-window))
            (speedbar-buf (get-buffer-create "*speedbar*")))
        (select-window (split-window current-window (- nn-speedbar-width) nn-speedbar-split-style))
        (setq nn-speedbar-window (selected-window))
        (switch-to-buffer speedbar-buf)
        (setq speedbar-frame (selected-frame)
              speedbar-buffer speedbar-buf
              dframe-attached-frame (selected-frame)
              speedbar-verbosity-level 0)
        (speedbar-mode)
        (speedbar-reconfigure-keymaps)
        (speedbar-update-contents)
        (speedbar-set-timer 1)
        (display-line-numbers-mode -1)
        (set-window-dedicated-p nn-speedbar-window t)
        (select-window current-window)))

    (defun nn-speedbar-close ()
      "Close speedbar window."
      (interactive)
      (if (nn-speedbar-exist-p)
          (let ((current-window (selected-window)))
            (select-window nn-speedbar-window)
            (set-window-dedicated-p nn-speedbar-window nil)
            (delete-window nn-speedbar-window)
            (setq nn-speedbar-window nil)
            (if (window-live-p current-window)
                (select-window current-window)))
        (message "Speedbar window does not exist.")))

    (defun nn-speedbar-kill-buffer-task ()
      (when (bound-and-true-p speedbar-buffer)
        (when (eq (current-buffer) speedbar-buffer)
          (setq speedbar-frame nil
                dframe-attached-frame nil
                speedbar-buffer nil)
          (speedbar-set-timer nil)
          (setq nn-speedbar-window nil))))

    (defun nn-speedbar-select-mru-window ()
      "Select the most recently used window."
      (select-window (get-mru-window)))

    (add-hook 'speedbar-before-visiting-file-hook #'nn-speedbar-select-mru-window)
    (add-hook 'speedbar-before-visiting-tag-hook #'nn-speedbar-select-mru-window)
    (add-hook 'speedbar-visiting-file-hook #'nn-speedbar-select-mru-window)
    (add-hook 'speedbar-visiting-tag-hook #'nn-speedbar-select-mru-window)
    (add-hook 'kill-buffer-hook #'nn-speedbar-kill-buffer-task)))

(use-package compile
  :ensure nil
  :hook
  (compilation-filter . ansi-color-compilation-filter)
  :bind (("C-c c" . compile)
         :map compilation-mode-map
         ("r" . compile)
         ("C-c C-k" . delete-process))
  :custom
  (compile-command "")
  (compilation-always-kill t)
  (compilation-ask-about-save nil)
  (compilation-max-output-line-length nil)
  (compilation-scroll-output 'first-error)
  (compilation-scroll-output t)
  (compilation-window-height 12)
  (compilation-skip-threshold 1)
  (compilation-transform-file-name-alist nil)
  (next-error-highlight t)
  (next-error-highlight-no-select t)
  :config
  (add-to-list 'compilation-error-regexp-alist-alist
               '(nn-custom-error
                 "\\([a-zA-Z0-9\\.]+\\)(\\([0-9]+\\)\\(,\\([0-9]+\\)\\)?) : \\(warning\\|error\\)"
                 1 2 (4) (5)))
  (add-to-list 'compilation-error-regexp-alist 'nn-custom-error))

(use-package comint
  :ensure nil
  :custom
  (comint-buffer-maximum-size 2048)
  (comint-prompt-read-only t))

(use-package isearch
  :ensure nil
  :bind (:map isearch-mode-map
              ([remap isearch-delete-char] . isearch-del-char))
  :custom
  (isearch-lazy-highlight t)
  (isearch-wrap-pause t)
  (isearch-allow-motion t)
  (isearch-motion-changes-direction t)
  (isearch-lazy-count t)
  (lazy-highlight-cleanup t)
  (lazy-count-prefix-format "%s/%s ")
  :config
  (defvar my-isearch--direction nil)
  (define-advice isearch-exit (:after nil)
    (setq-local my-isearch--direction nil))
  (define-advice isearch-repeat-forward (:after (_))
    (setq-local my-isearch--direction 'forward))
  (define-advice isearch-repeat-backward (:after (_))
    (setq-local my-isearch--direction 'backward)))

(use-package ibuffer
  :ensure nil
  :bind ("C-x C-b" . ibuffer)
  :hook (ibuffer-mode . (lambda () (ibuffer-switch-to-saved-filter-groups "main")))
  :custom
  (ibuffer-expert t)
  (ibuffer-display-summary nil)
  (ibuffer-use-other-window nil)
  (ibuffer-show-empty-filter-groups nil)
  (ibuffer-default-sorting-mode 'filename/process)
  (ibuffer-title-face 'font-lock-doc-face)
  (ibuffer-use-header-line t)
  (ibuffer-default-shrink-to-minimum-size nil)
  (ibuffer-formats
   '((mark " " (name 16 -1) " " filename)
     (mark modified read-only " "
           (name 18 18 :left :elide) " "
           (size 9 -1 :right) " "
           (mode 16 16 :left :elide) " "
           filename-and-process)))
  (ibuffer-saved-filter-groups
   '(("main"
      ("C/C++" (name . "\\.\\(c\\|cpp\\|cc\\|h\\|hpp\\|cppm\\|ixx\\)$"))
      ("Scripts" (name . "\\.\\(sh\\|lua\\|bat\\|cmd\\|ps1\\|py\\|pl\\)$"))
      ("Web" (or (name . "\\.\\(html?\\|xml\\|css\\|s[ac]ss\\|less\\|jsx?\\|tsx?\\|json\\|md\\)$")))
      ("Config" (or (name . "\\.\\(toml\\|ya?ml\\|ini\\|cfg\\|conf\\|gitignore\\)$")
                    (name . "^\\.clangd$")
                    (name . "^Doxyfile$")
                    (name . "^config\\.toml$")))
      ("Assets" (or (name . "\\.\\(png\\|jpe?g\\|svg\\|webp\\|bpm\\|ppm\\|mp[34]\\|mov\\|avi\\|obj\\)$")))
      ("Mail" (or (derived-mode . message-mode)
                  (name . "\\`\\*\\(Gnus\\|gnus\\|Article\\|Summary\\|Group\\|mail\\|message\\)")))
      ("Document" (name . "\\.\\(md\\|markdown\\|org\\|adoc\\|tex\\|pdf\\|rst\\|txt\\)$"))
      ("VC" (or (name . "\\*vc-")))
      ("LLM" (or (mode . gptel-mode)
                 (mode . gptel-chat-mode)))
      ("LSP" (or (name . "\\`\\*\\(EGLOT\\|eldoc\\|LSP\\|lsp-help\\|Flymake\\)")
                 (derived-mode . eglot--managed-mode)))
      ("Debug" (or (derived-mode . special-mode)
                   (name . "\\`\\*\\(Backtrace\\|debug\\|Messages\\|Warnings\\|Compile-Log\\|gud-\\|dap-\\)")
                   (mode . debugger-mode)
                   (mode . gdb-mi-mode)))
      ("Compile/Shell" (or (derived-mode . comint-mode)
                           (name . "\\`\\*\\(compilation\\|Async Shell Command\\)")))
      ("Dired" (mode . dired-mode))
      ("Emacs" (or (derived-mode . emacs-lisp-mode)
                   (name . "\\`\\*\\(Help\\|Custom\\|info\\|scratch\\)"))))))
  :config
  (define-ibuffer-column size
    (:name "Size" :inline t :header-mouse-map ibuffer-size-header-map)
    (file-size-human-readable (buffer-size))))

(provide 'init-advanced)
