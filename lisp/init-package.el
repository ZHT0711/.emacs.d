;;; -*- lexical-binding: t; -*-

(setq package-archives
      '(("gnu"     . "https://mirrors.tuna.tsinghua.edu.cn/elpa/gnu/")
        ("nongnu"  . "https://mirrors.tuna.tsinghua.edu.cn/elpa/nongnu/")
        ("melpa"   . "https://mirrors.tuna.tsinghua.edu.cn/elpa/melpa/")))
;; (setq package-archives
;;       '(("gnu"          . "https://elpa.gnu.org/packages/")
;;         ("nongnu"       . "https://elpa.nongnu.org/nongnu/")
;;         ("melpa-stable" . "https://stable.melpa.org/packages/")
;;         ("melpa"        . "https://melpa.org/packages/")))

(setq package-check-signature nil)

(require 'package)
(package-initialize)
(unless package-archive-contents (package-refresh-contents))

(require 'use-package)
(setq use-package-always-ensure nil)
(setq use-package-compute-statistics t)
(setq use-package-verbose t)

(use-package rainbow-delimiters
  :ensure t
  :hook (prog-mode . rainbow-delimiters-mode)
  :config
  (defun rainbow-no-braces (depth match loc)
    (if (memq (char-after loc) '(?\{ ?\}))
        nil
      (rainbow-delimiters-default-pick-face depth match loc)))
  (setq rainbow-delimiters-pick-face-function #'rainbow-no-braces))

(use-package savefold
  :ensure t
  :custom
  (savefold-backends '(outline org markdown hideshow))
  :config
  (savefold-mode 1))

(use-package multiple-cursors
  :ensure t
  :defer t
  :bind (("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-M->" . mc/skip-to-next-like-this)
         ("C-M-<" . mc/skip-to-previous-like-this)
         ("C-<mouse-1>" . mc/add-cursor-on-click)
         :map mc/keymap
         ("<escape>" . mc/keyboard-quit))
  :config
  (setq mc/always-run-for-all t)
  (add-to-list 'mc--default-cmds-to-run-once 'swiper-mc))

(use-package corfu
  :ensure t
  :defer t
  :bind (:map corfu-map
              ([tab] . corfu-next)
              ([backtab] . corfu-previous)
              ("<escape>" . corfu-quit)
              ("RET" . corfu-insert))
  :hook (eshell-mode . (lambda () (setq-local corfu-auto nil)))
  :init
  (global-corfu-mode t)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.5)
  (corfu-auto-prefix 3)
  (corfu-cycle t)
  (corfu-count 15)
  (corfu-max-width 120)
  (corfu-right-margin-width 0)
  (corfu-preview-current nil)
  (corfu-quit-at-boundary 'separator)
  (corfu-quit-no-match 'separator)
  :config
  (setq global-corfu-modes '((not erc-mode circe-mode help-mode
                                  gud-mode vterm-mode message-mode
                                  shell-mode eshell-mode comint-mode
                                  compilation-mode) t)))

(use-package nerd-icons
  :ensure t
  :custom
  (nerd-icons-font-family "Symbols Nerd Font Mono")
  :config
  (unless (member "Symbols Nerd Font Mono" (font-family-list))
    (nerd-icons-install-fonts t)))

(use-package nerd-icons-corfu
  :ensure t
  :after (corfu nerd-icons)
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)
  (setq
   nerd-icons-corfu-mapping
   `((array :style "cod" :icon "symbol_array" :face nerd-icons-cyan)
     (boolean :style "cod" :icon "symbol_boolean" :face nerd-icons-blue)
     (class :style "cod" :icon "symbol_class" :face nerd-icons-yellow)
     (color :style "cod" :icon "symbol_color" :face nerd-icons-orange)
     (command :style "cod" :icon "terminal" :face nerd-icons-purple)
     (constant :style "cod" :icon "symbol_constant" :face nerd-icons-silver)
     (constructor :style "cod" :icon "triangle_right" :face nerd-icons-purple)
     (enummember :style "cod" :icon "symbol_enum_member" :face nerd-icons-blue)
     (enum-member :style "cod" :icon "symbol_enum_member" :face nerd-icons-blue)
     (enum :style "cod" :icon "symbol_enum" :face nerd-icons-yellow)
     (event :style "cod" :icon "symbol_event" :face nerd-icons-orange)
     (field :style "cod" :icon "symbol_field" :face nerd-icons-blue)
     (file :fn nerd-icons-icon-for-file :face nerd-icons-silver)
     (folder :fn nerd-icons-icon-for-dir :face nerd-icons-yellow)
     (interface :style "cod" :icon "symbol_interface" :face nerd-icons-cyan)
     (keyword :style "cod" :icon "symbol_keyword" :face nerd-icons-blue)
     (macro :style "cod" :icon "symbol_misc" :face nerd-icons-pink)
     (magic :style "cod" :icon "wand" :face nerd-icons-purple)
     (method :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (function :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (module :style "cod" :icon "file_submodule" :face nerd-icons-cyan)
     (numeric :style "cod" :icon "symbol_numeric" :face nerd-icons-blue)
     (operator :style "cod" :icon "symbol_operator" :face nerd-icons-blue)
     (param :style "cod" :icon "symbol_parameter" :face nerd-icons-silver)
     (property :style "cod" :icon "symbol_property" :face nerd-icons-lblue)
     (reference :style "cod" :icon "references" :face nerd-icons-lblue)
     (snippet :style "cod" :icon "symbol_snippet" :face nerd-icons-green)
     (string :style "cod" :icon "symbol_string" :face nerd-icons-dmaroon)
     (struct :style "cod" :icon "symbol_structure" :face nerd-icons-yellow)
     (text :style "cod" :icon "text_size" :face nerd-icons-silver)
     (typeparameter :style "cod" :icon "list_unordered" :face nerd-icons-cyan)
     (type-parameter :style "cod" :icon "list_unordered" :face nerd-icons-cyan)
     (unit :style "cod" :icon "symbol_ruler" :face nerd-icons-silver)
     (value :style "cod" :icon "symbol_field" :face nerd-icons-lblue)
     (variable :style "cod" :icon "symbol_variable" :face nerd-icons-blue))))

(use-package eldoc-box
  :ensure t
  :diminish eldoc-box-hover-at-point-mode
  :hook (eldoc-mode . eldoc-box-hover-at-point-mode)
  :custom
  (eldoc-box-offset 0)
  (eldoc-box-lighter nil)
  (eldoc-box-only-multi-line nil)
  (eldoc-box-clear-with-C-g t)
  (eldoc-box-fringe-use-same-bg t)
  (eldoc-box-max-pixel-width 640)
  (eldoc-box-max-pixel-height 640)
  :config
  (setf (alist-get 'left-fringe eldoc-box-frame-parameters) 8)
  (setf (alist-get 'right-fringe eldoc-box-frame-parameters) 8))

(use-package magit
  :ensure t
  :defer t
  :custom
  (magit-define-global-key-bindings 'recommended))

(provide 'init-package)
