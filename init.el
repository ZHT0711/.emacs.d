;;; -*- lexical-binding: t -*-
(require 'cl-lib)
(require 'init-package)
(require 'init-def)
(require 'init-font)
(require 'init-display)
(require 'init-mode-line)
(require 'init-base)
(require 'init-advanced)
(require 'init-editor)
(require 'init-lang)
(require 'init-lsp)
(require 'init-debug)
(require 'init-diagnostics)
(require 'init-completion)
(require 'init-navigation)
(require 'init-imenu)
(require 'init-wsl)
(require 'init-vc)
(require 'init-www)
(require 'init-utils)
(require 'init-terminal)
(require 'init-render)
(require 'init-evil)
(require 'init-keybind)
(require 'init-context-menu)
(require 'init-home)
(require 'nn-world-theme)

;;在标题栏显示路径~
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                   (abbreviate-file-name (buffer-file-name))
                 "%b"))))

;;This is a little shortcut for me to open the file
(defun my-smart-find-file ()
  "有选区时用选区内容打开文件，否则使用 `find-file-at-point'。"
  (interactive)
  (if (use-region-p)
      (let ((file (buffer-substring-no-properties
                   (region-beginning) (region-end))))
        (find-file file))
    (call-interactively 'find-file-at-point)))
(global-set-key (kbd "C-x C-f") 'my-smart-find-file)

;; 设置为相对行号模式
(setq display-line-numbers-type 'relative)

;; 让当前行显示绝对行号（而不是0）
(setq display-line-numbers-current-absolute t)

(setq-default custom-file "~/.emacs.d/custom.el")
(load custom-file)

(setq-default custom-file "~/.emacs.d/custom.el")
(load custom-file)
