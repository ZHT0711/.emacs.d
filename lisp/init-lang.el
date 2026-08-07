;;; -*- lexical-binding: t -*-
(require 'treesit)
(require 'lang-cc)
(require 'lang-lisp)
(require 'lang-javascript)
(require 'lang-web)
(require 'lang-shell)
(require 'lang-org)
(require 'lang-markdown)
(require 'lang-json)
(require 'lang-yaml)

(use-package prog-mode
  :ensure nil
  :hook (prog-mode . prettify-symbols-mode))

(use-package text-mode
  :ensure nil
  :custom (text-mode-ispell-word-completion nil)
  :config
  (add-to-list 'auto-mode-alist '("/.gitignore\\'" . text-mode))
  (add-to-list 'auto-mode-alist '("/INSTALL\\'" . text-mode))
  (add-to-list 'auto-mode-alist '("/LICENSE\\'" . text-mode)))

(use-package syntax
  :ensure nil
  :config
  (setq syntax-wholeline-max 1000))

(provide 'init-lang)
