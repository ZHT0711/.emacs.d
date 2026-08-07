;;; -*- lexical-binding: t -*-
(require 'package)
(setq package-install-upgrade-built-in nil
      package-check-signature nil
      package-archives
      '(("melpa-cn" . "http://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")
        ("gnu-cn"   . "http://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")))
(package-initialize)

(require 'use-package)
(setq use-package-always-ensure t
      use-package-always-defer t
      use-package-expand-minimally t
      use-package-enable-imenu-support t)

(use-package no-littering
  :defer nil
  :custom
  (no-littering-var-directory "~/.emacs.d/var/")
  (no-littering-etc-directory "~/.emacs.d/etc/")
  :config
  (no-littering-theme-backups)
  (setq nn-markdown-preview--file (no-littering-expand-var-file-name ".markdown-preview.html")
        savefold-directory (no-littering-expand-var-file-name "savefold/")
        message-directory (no-littering-expand-etc-file-name "mail/")
        message-auto-save-directory (no-littering-expand-etc-file-name "mail/drafts/")))

(provide 'init-package)
