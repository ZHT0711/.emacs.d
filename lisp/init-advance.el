;; -*- lexical-binding: t -*-

;; fold
(defvar nn-fold-string "...")
(defface nn-fold-face '((t :inherit font-lock-escape-face)) "fold face.")

(defun nn-toggle-fold ()
  (interactive)
  (cond
   ((and (bound-and-true-p hs-minor-mode)
         (hs-already-hidden-p))
    (hs-show-block))
   ((bound-and-true-p hs-minor-mode)
    (hs-hide-block))
   ((bound-and-true-p outline-minor-mode)
    (outline-toggle-children))))

(defun nn-fold-hide-all ()
  (interactive)
  (cond
   ((bound-and-true-p hs-minor-mode) (hs-hide-all))
   ((bound-and-true-p outline-minor-mode) (outline-hide-body))))

(defun nn-fold-show-all ()
  (interactive)
  (cond
   ((bound-and-true-p hs-minor-mode) (hs-show-all))
   ((bound-and-true-p outline-minor-mode) (outline-show-all))))

(use-package hideshow
  :hook
  ((python-mode . hs-minor-mode)
   (ruby-mode . hs-minor-mode)
   (java-mode . hs-minor-mode)
   (php-mode . hs-minor-mode)
   (sh-mode . hs-minor-mode)
   (emacs-lisp-mode . hs-minor-mode)
   (lisp-mode . hs-minor-mode)
   (c-mode . hs-minor-mode)
   (c++-mode . hs-minor-mode)
   (c-ts-mode . hs-minor-mode)
   (js-mode . hs-minor-mode)
   (js-ts-mode . hs-minor-mode)
   (typescript-mode . hs-minor-mode)
   (typescript-ts-mode . hs-minor-mode)
   (html-mode . hs-minor-mode)
   (css-mode . hs-minor-mode)
   (css-ts-mode . hs-minor-mode))
  :commands (hs-toggle-hiding
             hs-hide-block
             hs-hide-level
             hs-show-all
             hs-hide-all)
  :custom
  (hs-ellipsis nn-fold-string)
  (hs-hide-comments-when-hiding-all nil)
  :config
  (defun my-fold-hideshow-set-up-overlay-fn (ov)
    (when (eq 'code (overlay-get ov 'hs))
      (overlay-put ov 'display (propertize nn-fold-string 'face 'nn-fold-face))))

  (setq hs-set-up-overlay 'my-fold-hideshow-set-up-overlay-fn)

  (unless (assq 't hs-special-modes-alist)
    (setq hs-special-modes-alist
          (append
           '((nxml-mode "<!--\\|<[^/>]*[^/]>"
                        "-->\\|</[^/>]*[^/]>"
                        "<!--" sgml-skip-tag-forward nil))
           hs-special-modes-alist
           '((t))))))

(use-package outline
  :hook
  ((org-mode . outline-minor-mode)
   (markdown-mode . outline-minor-mode)
   (latex-mode . outline-minor-mode)
   (conf-mode . outline-minor-mode))
  :custom
  (outline-ellipsis nn-fold-string))

(keymap-global-set "S-<return>"
                   #'nn-toggle-fold)
(keymap-global-set "C-c [" #'nn-fold-show-all)
(keymap-global-set "C-c ]" #'nn-fold-hide-all)

;; eldoc
(use-package eldoc
  :defer t
  :custom
  (eldoc-idle-delay 0.7)
  (eldoc-idle-delay-visible-only t)
  (eldoc-echo-area-prefer-doc-buffer t)
  (eldoc-echo-area-use-multiline-p nil)
  (eldoc-echo-area-display-truncation-message nil))

;; ido
(use-package ido
  :hook
  (ido-mode . (lambda () (ido-everywhere t)))
  :bind
  (:map ido-common-completion-map
        ("C-w" . ido-delete-backward-word-updir)
        ("C-n" . ido-next-match)
        ("C-p" . ido-prev-match)
        ("<down>" . ido-next-match)
        ("<up>" . ido-prev-match))
  (:map ido-file-completion-map
        ("C-w" . ido-delete-backward-word-updir)
        ("~" . (lambda () (interactive)
                 (if (looking-back "/" (point-min))
                     (insert "~/")
                   (call-interactively #'self-insert-command)))))
  (:map ido-file-dir-completion-map
        ("C-n" . ido-next-match)
        ("C-p" . ido-prev-match)
        ("<down>" . ido-next-match)
        ("<up>" . ido-prev-match))
  :init
  (ido-mode 1)
  :custom
  (ido-max-prospects 5)
  (ido-enable-flex-matching t)
  (ido-auto-merge-work-directories-length -1)
  (ido-confirm-unique-completion t)
  (ido-case-fold t)
  (ido-create-new-buffer 'always)
  (ido-ignore-buffers '("\\` " "^\\*ESS\\*" "^\\*Messages\\*" "^\\*[Hh]elp" "^\\*Buffer"
                        "^\\*.*Completions\\*$" "^\\*Ediff" "^\\*tramp" "^\\*cvs-" "_region_"
                        " output\\*$" "^TAGS$" "^\*Ido"))
  (ido-ignore-files '("\\`.DS_Store$" "Icon\\?$")))

;; speedbar
(use-package speedbar
  :defer t
  :bind ("C-|" . nn-speedbar-toggle)
  :hook
  ((speedbar-before-visiting-file . (lambda () (select-window (get-mru-window))))
   (speedbar-before-visiting-tag . (lambda () (select-window (get-mru-window))))
   (speedbar-visiting-file . (lambda () (select-window (get-mru-window))))
   (speedbar-visiting-tag . (lambda () (select-window (get-mru-window))))
   (kill-buffer . (lambda ()
                    (when (bound-and-true-p speedbar-buffer)
                      (when (eq (current-buffer) speedbar-buffer)
                        (setq speedbar-frame nil
                              dframe-attached-frame nil
                              speedbar-buffer nil)
                        (speedbar-set-timer nil)
                        (setq nn-speedbar-window nil))))))
  :custom
  (speedbar-use-images nil)
  (speedbar-hide-button-brackets-flag t)
  (speedbar-smart-directory-expand-flag t)
  (speedbar-mode-specific-contents-flag t)
  (speedbar-track-mouse-flag t)
  (speedbar-use-tool-tips-flag t)
  (speedbar-show-unknown-files t)
  (speedbar-verbosity-level 0)
  (speedbar-directory-unshown-regexp "^\\(\.\.*$\\)'")
  :config
  (defvar nn-speedbar-window nil)
  (defvar nn-speedbar-width 30)
  (defvar nn-speedbar-split-style 'right)

  (defun nn-speedbar-toggle ()
    "Toggle speedbar window."
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
      (message "Speedbar window is not exist.")))

  (add-hook 'kill-buffer-hook
            (lambda ()
              (when (and (boundp 'speedbar-buffer)
                         speedbar-buffer
                         (eq (current-buffer) speedbar-buffer))
                (setq speedbar-frame nil
                      dframe-attached-frame nil
                      speedbar-buffer nil
                      speedbar-set-timer nil
                      nn-speedbar-window nil)))))

;; diread
(use-package dired
  :defer t
  :hook (dired-mode . auto-revert-mode)
  :bind (:map dired-mode-map ("_" . dired-create-empty-file))
  :commands dired-jump
  :custom
  (dired-dwim-target t)
  (dired-auto-revert-buffer t)
  (dired-recursive-deletes 'top)
  (dired-recursive-copies 'always)
  (dired-create-destination-dirs 'always)
  (dired-no-confirm '(move copy delete))
  (dired-listing-switches "-alh --group-directories-first")
  :config
  (advice-add 'dired-do-rename :after (lambda (&rest _) (dired-unmark-all-marks)))
  (put 'dired-find-alternate-file 'disabled nil))

;; ibuffer
(use-package ibuffer
  :defer t
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
  (ibuffer-formats '((mark " " (name 16 -1) " " filename)
                     (mark modified read-only " "
                           (name 18 18 :left :elide) " "
                           (size 9 -1 :right) " "
                           (mode 16 16 :left :elide) " "
                           filename-and-process)))
  (ibuffer-saved-filter-groups
   '(("main"
      ("C/C++" (or
                (mode . c++-mode)
                (mode . c++-ts-mode)
                (mode . c-mode)
                (mode . c-ts-mode)
                (mode . c-or-c++-ts-mode)))
      ("Web" (or
              (mode . mhtml-mode)
              (mode . html-mode)
              (mode . web-mode)
              (mode . nxml-mode)
              (mode . css-mode)
              (mode . sass-mode)
              (mode . js-mode)
              (mode . rjsx-mode)))
      ("Assets" (or
                 (name . "\.png$")
                 (name . "\.jpg$")
                 (name . "\.jpeg$")
                 (name . "\.svg$")
                 (name . "\.webp$")
                 (name . "\.bpm$")
                 (name . "\.ppm$")
                 (name . "\.mp4$")
                 (name . "\.mp3$")
                 (name . "\.mov$")
                 (name . "\.avi$")
                 (name . "\.obj$")))
      ("Config" (or
                 (mode . conf-mode)
                 (mode . conf-toml-mode)
                 (mode . toml-ts-mode)
                 (mode . conf-windows-mode)
                 (mode . yaml-mode)
                 (name . "^\\.clangd$")
                 (name . "^\\.gitignore$")
                 (name . "^Doxyfile$")
                 (name . "^config\\.toml$")))
      ("Mail" (or
               (mode . gnus-group-mode)
               (mode . gnus-summary-mode)
               (mode . gnus-article-mode)
               (mode . message-mode)))
      ("Document" (or
                   (mode . markdown-mode)
                   (mode . org-mode)
                   (mode . adoc-mode)
                   (name . "\.tex$")
                   (name . "\.pdf$")))
      ("Scripts" (or
                  (mode . shell-script-mode)
                  (mode . sh-mode)
                  (mode . lua-mode)
                  (mode . bat-mode)))
      ("Magit" (or
                (mode . magit-blame-mode)
                (mode . magit-cherry-mode)
                (mode . magit-diff-mode)
                (mode . magit-log-mode)
                (mode . magit-process-mode)
                (mode . magit-status-mode)))
      ("LLM" (or
              (mode . gptel-mode)
              (mode . gptel-chat-mode)))
      ("LSP" (or (name . "\\*EGLOT")
                 (name . "\\*eldoc")
                 (name . "\\*LSP")
                 (name . "\\*lsp-help")
                 (name . "\\*Flymake")
                 (mode . eglot--managed-mode)))
      ("Debug" (or
                (mode . debugger-mode)
                (mode . backtrace-mode)
                (mode . gdb-mi-mode)
                (mode . dap-ui-mode)
                (mode . dap-ui-repl-mode)
                (mode . dap-ui-breakpoints-mode)
                (mode . dap-ui-sessions-mode)
                (name . "^\\*Backtrace\\*$")
                (name . "^\\*debug\\*$")
                (name . "^\\*Messages\\*$")
                (name . "^\\*Warnings\\*$")
                (name . "^\\*Compile-Log\\*$")
                (name . "^\\*gud-.*\\*$")
                (name . "^\\*dap-.*\\*$")))
      ("Dired" (mode . dired-mode))
      ("Compile/Shell" (or (mode . shell-mode)
                           (mode . term-mode)
                           (mode . eshell-mode)
                           (name . "^\\*compilation\\*")
                           (name . "^\\*Async Shell Command\\*")))
      ("Emacs" (or
                (mode . emacs-lisp-mode)
                (name . "^\\*Help\\*$")
                (name . "^\\*Custom.*")
                (name . "^\\*Org Agenda\\*$")
                (name . "^\\*info\\*$")
                (name . "^\\*scratch\\*$"))))))
  :config
  (define-ibuffer-column size
    (:name "Size" :inline t :header-mouse-map ibuffer-size-header-map)
    (file-size-human-readable (buffer-size))))

;; eww
(use-package eww
  :defer t
  :config
  (defun +eww-open-in-fullscreen-if-interactive-a (fn &rest args)
    (if (called-interactively-p 'any)
        (apply fn args)
      (let (display-buffer-alist)
        (apply fn args))))
  (advice-add 'eww :around #'+eww-open-in-fullscreen-if-interactive-a)

  (defun +eww-page-title-or-url ()
    "Return the page title or URL to use as buffer name."
    (or (plist-get eww-data :title)
        (plist-get eww-data :url)
        ""))

  (if (boundp 'eww-auto-rename-buffer)
      (setq eww-auto-rename-buffer #'+eww-page-title-or-url)  ;; Emacs 29.1+
    ;; Emacs 28
    (defun +eww--rename-buffer-to-page-title-or-url-h (&rest _)
      (rename-buffer (+eww-page-title-or-url)))
    (add-hook 'eww-after-render-hook #'+eww--rename-buffer-to-page-title-or-url-h)
    (advice-add 'eww-back-url :after #'+eww--rename-buffer-to-page-title-or-url-h)
    (advice-add 'eww-forward-url :after #'+eww--rename-buffer-to-page-title-or-url-h)))

(provide 'init-advance)
