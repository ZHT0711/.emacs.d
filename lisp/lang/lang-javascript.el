;;; -*- lexical-binding: t -*-
(use-package js
  :ensure nil
  :mode ("\\.[mc]?js\\'" . js-mode)
  :custom
  (js-chain-indent t)
  (js-indent-level 2))

(use-package typescript-ts-mode
  :ensure nil
  :if (or (treesit-language-available-p 'typescript)
          (treesit-language-available-p 'tsx))
  :mode
  ("\\.ts\\'" . typescript-ts-mode)
  ("\\.tsx\\'" . tsx-ts-mode)
  :hook
  (tsx-ts-mode . eglot-ensure)
  (tsx-ts-mode . my-ts-eldoc-box-setup)
  (typescript-ts-mode . eglot-ensure)
  (typescript-ts-mode . my-ts-eldoc-box-setup)
  :init
  (add-to-list 'treesit-language-source-alist
               '(typescript . ("https://github.com/tree-sitter/tree-sitter-typescript"
                               nil "typescript/src")))
  (add-to-list 'treesit-language-source-alist
               '(tsx . ("https://github.com/tree-sitter/tree-sitter-typescript"
                        nil "tsx/src")))
  :config
  (defun my-ts-eldoc-box-setup ()
    "Setup eldoc-box for TypeScript/TSX modes."
    (add-hook 'eldoc-box-buffer-setup-hook #'eldoc-box-prettify-ts-errors nil t)))

(provide 'lang-javascript)
