;; -*- lexical-binding: t; -*-

(setq-default next-error-find-buffer-function #'next-error-buffer-unnavigated-current)

(use-package flymake
  :defer t
  :bind (:map flymake-mode-map
              ("<f8>"       . flymake-goto-next-error)
              ("<S-f8>"     . flymake-goto-prev-error)
              ("<C-f8>"     . flymake-show-buffer-diagnostics))
  :custom
  (flymake-mode-line-format nil)
  (flymake-no-changes-timeout nil)
  (lymake-start-on-flymake-mode t)
  (flymake-suppress-zero-diagostics t)
  (flymake-fringe-indicator-position nil)
  (flymake-margin-indicator-position nil)
  (flymake-show-diagnostics-at-end-of-line nil)
  (flymake-diagnostic-functions nil)
  (flymake-fringe-indicator-position 'right-fringe)
  (flymake-wrap-around nil)
  :config
  ;; saveing check
  (cl-defmethod eglot-handle-notification :after
    (_server (_method (eql textDocument/publishDiagnostics)) &key uri
             &allow-other-keys)
    (when-let ((buffer (find-buffer-visiting (eglot-uri-to-path uri))))
      (with-current-buffer buffer
        (if (and (eq nil flymake-no-changes-timeout)
                 (not (buffer-modified-p)))
            (flymake-start t)))))

  (add-hook 'flymake-mode-hook
            (lambda ()
              (setq-local next-error-function #'flymake-goto-next-error)))
  ;; CVE-2024-53920 安全修复（只在项目 buffer 里检查 elisp）
  (advice-add 'elisp-flymake-byte-compile :before-while
              (lambda (&rest _) (project-current))))

(use-package eglot
  :defer t
  :bind (:map eglot-mode-map
              ("<f2>"        . eglot-rename)
              ("<f12>"       . xref-find-definitions)
              ("<S-f12>"     . xref-find-references)
              ("<C-f12>"     . eglot-find-implementation)
              ("<C-S-f12>"   . eglot-find-typeDefinition))
  :custom
  (eglot-sync-connect 1)
  (eglot-autoshutdown t)
  (eglot-shutdown-timeout 5)
  (eglot-prefer-plaintext t) ; Markdown 渲染有问题，先关闭，后续换 treesit
  (eglot-auto-display-help-buffer nil)
  (eglot-code-action-indications '(eldoc-hint))
  (eglot-report-progress nil)
  (eglot-events-buffer-size 0)
  (eglot-ignored-server-capabilities '(:inlayHintProvider :documentHighlightProvider))
  :config
  (add-to-list 'eglot-server-programs
               '((c++-ts-mode) .
                 ("clangd"
                  "--clang-tidy"
                  "--function-arg-placeholders=0"
                  "--header-insertion=never"
                  "--background-index"
                  "--limit-results=15"
                  "--query-driver=gcc,g++")))
  (with-eval-after-load 'jsonrpc (fset #'jsonrpc--log-event #'ignore))
  :hook ((js-ts-mode . eglot-ensure)
         (typescript-ts-mode . eglot-ensure)
         (c-ts-mode . eglot-ensure)
         (c++-ts-mode . eglot-ensure)))

(use-package apheleia
  :ensure t
  :defer t
  :bind
  ("<f1>" . apheleia-format-buffer)
  :hook
  (apheleia-inhibit-functions . my-apheleia-inhibit-p)
  :custom
  (apheleia-log-only-errors t)
  :config
  (add-to-list 'apheleia-mode-alist '(sh-mode . shfmt))
  (add-to-list 'apheleia-mode-alist '(cuda-mode . clang-format))
  (add-to-list 'apheleia-mode-alist '(protobuf-mode . clang-format))

  (defun my-apheleia-inhibit-p ()
    (in)
    (or (eq major-mode 'fundamental-mode)
        (string-blank-p (buffer-name))
        (eq +format-on-save-disabled-modes t)))

  (setf (alist-get 'clang-format apheleia-formatters)
        `("clang-format"
          "-assume-filename"
          (or (apheleia-formatters-local-buffer-file-name)
              (apheleia-formatters-mode-extension)
              ".c")
          (when apheleia-formatters-respect-indent-level
            (unless (locate-dominating-file default-directory ".clang-format")
              (format "--style={IndentWidth: %d}" c-basic-offset)))))

  (dolist (formatter '(prettier prettier-css prettier-html prettier-javascript
                                prettier-json prettier-scss prettier-svelte
                                prettier-typescript prettier-yaml))
    (setf (alist-get formatter apheleia-formatters)
          '("prettier" "--stdin-filepath"
            (or (apheleia-formatters-local-buffer-file-name)
                (apheleia-formatters-mode-extension)
                ".js")))))

(provide 'init-lsp)
