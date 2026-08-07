;;; -*- lexical-binding: t -*-
(use-package xref
  :autoload xref-show-definitions-completing-read
  :bind (("M-g ." . xref-find-definitions)
         ("M-g ," . xref-go-back))
  :init
  (when (executable-find "rg")
    (setq xref-search-program 'ripgrep))
  (setq xref-show-definitions-function #'xref-show-definitions-completing-read
        xref-show-xrefs-function #'xref-show-definitions-completing-read))

(use-package eglot
  :ensure nil
  :bind
  (("<f2>"      . eglot-rename)
   ("<f12>"     . xref-find-definitions)
   ("S-<f12>"   . xref-find-references)
   ("C-<f12>"   . eglot-find-implementation)
   ("C-S-<f12>" . eglot-find-typeDefinition)
   ("C-."       . eglot-code-action-quickfix))
  :custom
  (eglot-autoshutdown t)
  (eglot-code-action-indications '(left-fringe))
  (eglot-events-buffer-config '(:size 0 :format 'short))
  (eglot-ignored-server-capabilities
   '(:inlayHintProvider
     :documentHighlightProvider
     :foldingRangeProvider))
  :config
  (define-fringe-bitmap 'eglot--fringe-action
    [#b0000000000000000
     #b0000001111000000
     #b0000111111110000
     #b0001111111111000
     #b0001100000011000
     #b0001100100011000
     #b0001100110011000
     #b0001100000011000
     #b0001111111111000
     #b0000111111110000
     #b0000111111100000
     #b0000001111000000
     #b0000001111000000
     #b0000001111000000
     #b0000001111000000
     #b0000000000000000]
    16 16 'center)

  ;; jsonrpc 的日志忽略掉
  (fset #'jsonrpc--log-event #'ignore)

  ;; 抑制 eglot 加的face
  (when (< emacs-major-version 31)
    (define-advice eglot-completion-at-point (:filter-return (cap) no-face)
      (when-let* ((props (nthcdr 3 cap))
                  (fn (plist-get props :annotation-function)))
        (setf (plist-get props :annotation-function)
              (lambda (proxy) (substring-no-properties (funcall fn proxy)))))
      cap)))

(provide 'init-lsp)
