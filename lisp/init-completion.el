;;; -*- lexical-binding: t -*-
(defun my-ido-recentf-open ()
  (interactive)
  (let ((file (completing-read "Find recent file: " recentf-list nil t)))
    (if (and file (file-exists-p file))
        (find-file file)
      (message "File open failed"))))

(use-package dabbrev
  :ensure nil
  :custom
  (dabbrev-case-replace nil)
  (dabbrev-downcase-means-case-replace nil)
  (dabbrev-case-distinction nil))

(use-package ido
  :ensure nil
  :if (< emacs-major-version 27)
  :bind
  (("C-x C-r" . my-ido-recentf-open)
   (:map ido-common-completion-map
         ("C-w" . ido-delete-backward-word-updir)
         ("C-n" . ido-next-match)
         ("C-p" . ido-prev-match)
         ("<down>" . ido-next-match)
         ("<up>" . ido-prev-match))
   (:map ido-file-completion-map
         ("C-w" . ido-delete-backward-word-updir))
   (:map ido-file-dir-completion-map
         ("C-n" . ido-next-match)
         ("C-p" . ido-prev-match)
         ("<down>" . ido-next-match)
         ("<up>" . ido-prev-match)))
  :init (ido-mode 1)
  :custom
  (ido-everywhere t)
  (ido-max-prospects 5)
  (ido-enable-flex-matching t)
  (ido-auto-merge-work-directories-length -1)
  (ido-confirm-unique-completion t)
  (ido-case-fold t)
  (ido-create-new-buffer 'always)
  (ido-ignore-files '("\\`.DS_Store$" "Icon\\?$"))
  (ido-ignore-buffers '("\\` " "^\\*ESS\\*" "^\\*Messages\\*" "^\\*[Hh]elp" "^\\*Buffer"
                        "^\\*.*Completions\\*$" "^\\*Ediff" "^\\*tramp" "^\\*cvs-" "_region_"
                        " output\\*$" "^TAGS$" "^\*Ido")))

(use-package icomplete
  :ensure nil
  :if (>= emacs-major-version 27)
  :bind ("C-x C-r" . my-ido-recentf-open)
  :init
  (fido-mode 1)
  (if (window-system)
      (fido-vertical-mode 1)
    (add-hook 'after-make-frame-functions
              (lambda (frame)
                (when (and (display-graphic-p frame)
                           (not fido-vertical-mode))
                  (fido-vertical-mode 1)))))
  ;; (icomplete-mode 1)
  ;; (icomplete-vertical-mode 1)
  :custom
  (icomplete-max-delay-chars 3)
  (icomplete-show-matches-on-no-input nil)
  (icomplete-hide-common-prefix nil)
  (icomplete-tidy-shadowed-file-names t))

(use-package fido-frame
  :vc (:url "https://github.com/zHaOdANiuu/fido-frame" :rev :newest)
  :init (fido-frame-mode)
  :custom (fido-frame-left 0.25)
          (fido-frame-width 0.5)
  :config
  ;; 超长提示自动折行：按 minibuffer 内容行数扩展 child frame 高度
  (defun my-fido-frame-resize-by-content (&rest _)
    "Resize fido-frame child frame to fit minibuffer content lines."
    (condition-case nil
        (when-let* ((frame fido-frame--frame)
                    ((frame-live-p frame))
                    ((window-live-p (active-minibuffer-window)))
                    (h (with-current-buffer (window-buffer (active-minibuffer-window))
                         (count-screen-lines (point-min) (point-max)))))
          (set-frame-height frame (min (max 1 (1+ h)) fido-frame-max-height)))))

  (defun my-fido-frame-minibuffer-setup ()
    "Track minibuffer content changes to resize the child frame."
    (add-hook 'after-change-functions #'my-fido-frame-resize-by-content nil t)
    (my-fido-frame-resize-by-content))

  (defun my-fido-frame-minibuffer-exit ()
    "Stop tracking minibuffer content changes."
    (remove-hook 'after-change-functions #'my-fido-frame-resize-by-content t))

  (advice-add 'fido-frame-setup :after #'my-fido-frame-minibuffer-setup)
  (advice-add 'fido-frame-exit :after #'my-fido-frame-minibuffer-exit)
  (when (and (display-graphic-p)
             (eq system-type 'windows-nt))
    (define-advice fido-frame-setup (:after () my-draw-input-switch-to-child)
      (nn-ime-end)
      (nn-ime-begin (cl-parse-integer (frame-parameter fido-frame--frame 'window-id))))

    (define-advice fido-frame-exit (:after () my-draw-input-switch-to-main)
      (nn-ime-end)
      (nn-ime-begin (cl-parse-integer (frame-parameter nil 'window-id))))))
(use-package completion-preview
  :ensure nil
  :if (and (>= emacs-major-version 30)
           (eq nn-completion-style 'completion-preview))
  :bind (:map completion-preview-active-mode-map
              ("C-n" . completion-preview-next-candidate)
              ("C-p" . completion-preview-prev-candidate)
              ("C-l" . (lambda () (interactive)
                         (completion-preview-hide)
                         (completion-preview-next-candidate))))
  :custom
  (completion-preview-ignore-case t)
  (completion-preview-minimum-symbol-length nil)
  (completion-preview-completion-styles '(basic partial-completion initials orderless)))

(use-package yasnippet
  :hook (after-init . yas-global-mode))

(use-package yasnippet-snippets
  :hook (simpc-mode . (lambda () (yas-activate-extra-mode 'c++-mode))))

(use-package yasnippet-capf
  :commands yasnippet-capf
  :functions cape-capf-super eglot-completion-at-point
  :hook (((conf-mode prog-mode text-mode) . my-yasnippet-capf-h)
         (eglot-managed-mode . my-eglot-capf))
  :init
  (defun my-yasnippet-capf-h ()
    (add-to-list 'completion-at-point-functions #'yasnippet-capf))

  ;; Making a Cape Super Capf for Eglot
  ;; https://github.com/minad/corfu/wiki#making-a-cape-super-capf-for-eglot
  (defun my-eglot-capf ()
    (setq-local completion-at-point-functions
                (list (cape-capf-super
                       #'eglot-completion-at-point
                       #'yasnippet-capf)))))

(use-package corfu
  :if (eq nn-completion-style 'corfu)
  :commands (corfu-quit)
  :bind (:map corfu-map
              ([tab] . corfu-next)
              ([backtab] . corfu-previous)
              ("<escape>" . corfu-quit)
              ("RET" . corfu-insert))
  :custom
  (global-corfu-mode 1)
  (global-corfu-modes '((not erc-mode help-mode gud-mode) t))
  (global-corfu-minibuffer (lambda () (not (featurep 'fido-frame))))
  (corfu-cycle t)
  (corfu-on-exact-match nil)
  (corfu-count 10)
  (corfu-max-width 120)
  (corfu-left-margin-width 0)
  (corfu-right-margin-width 0)
  (corfu-preview-current nil)
  (corfu-quit-at-boundary t)
  (corfu-quit-no-match 'separator)
  :config
  (defun my-corfu-smart-sep-toggle-escape ()
    "Insert `corfu-separator' or toggle escape if it's already there."
    (interactive)
    (cond ((and (char-equal (char-before) corfu-separator)
                (char-equal (char-before (1- (point))) ?\\))
           (save-excursion (delete-char -2)))
          ((char-equal (char-before) corfu-separator)
           (save-excursion (backward-char 1)
                           (insert-char ?\\)))
          ((call-interactively #'corfu-insert-separator))))
  (add-to-list 'corfu-continue-commands #'my-corfu-smart-sep-toggle-escape)

  (define-advice ispell-completion-at-point
      (:around (fn &rest args) my-corfu--auto-disable-ispell)
    "If ispell isn't properly set up, only complain once per session."
    (condition-case-unless-debug e
        (apply fn args)
      (error
       (message "Error: %s" (error-message-string e))
       (message "Auto-disabling `text-mode-ispell-word-completion'")
       (setq text-mode-ispell-word-completion nil)
       (remove-hook 'completion-at-point-functions #'ispell-completion-at-point t)))))

(use-package corfu-auto
  :ensure nil
  :custom
  (corfu-auto t)
  (corfu-auto-delay (if (eq system-type 'darwin) 0.4 0.24))
  (corfu-auto-prefix 2))

;; (use-package corfu-popupinfo
;;   :ensure nil
;;   :hook (corfu-mode . corfu-popupinfo-mode)
;;   :custom (corfu-popupinfo-delay '(0.5 . 1.0)))

(provide 'init-completion)
