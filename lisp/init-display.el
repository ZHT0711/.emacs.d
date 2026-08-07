;;; -*- lexical-binding: t -*-
(use-package fringe
  :ensure nil
  :custom
  (fringe-mode '(16 . 16))
  (indicate-buffer-boundaries nil)
  (overflow-newline-into-fringe nil)
  :config (setq-default fringes-outside-margins t))

(use-package tooltip
  :ensure nil
  :custom (tooltip-resize-echo-area t))

(use-package display-line-numbers
  :ensure nil
  :hook ((prog-mode text-mode conf-mode) . display-line-numbers-mode)
  :custom
  (display-line-numbers-grow-only t)
  (display-line-numbers-width 3)
  (display-line-numbers-widen t))

(use-package paren
  :ensure nil
  :custom
  (show-paren-style 'parenthesis)
  (show-paren-context-when-offscreen 'overlay)
  (blink-matching-paren-highlight-offscreen t)
  :config
  (show-paren-mode t)
  (define-advice show-paren--show-context-in-overlay (:after (_text) no-box)
    (when show-paren--context-overlay
      (overlay-put show-paren--context-overlay
                   'face '(:inherit default :box nil :height 0.9)))))

(use-package whitespace
  :ensure nil
  :hook
  (((org-mode
     python-mode python-ts-mode
     yaml-mode yaml-ts-mode
     markdown-mode markdown-ts-mode
     makefile-mode makefile-gmake-mode)
    . whitespace-mode)
   (before-save . delete-trailing-whitespace))
  :custom
  (whitespace-line-column nil)
  (whitespace-style '(face indentation tabs tab-mark spaces space-mark))
  (whitespace-display-mappings
   '((tab-mark ?\t [?→ ?\t])
     (space-mark ?\  [?·] [?.])))
  :config
  ;; HACK: Suppress space display mapping marks in overlays.
  (set-face-attribute 'nobreak-space nil :underline nil)
  (define-advice overlay-put (:filter-args (args) nn-bypass-whitespace-display)
    (if-let* ((prop (nth 1 args))
              (val (nth 2 args))
              ((eq prop 'display))
              ((stringp val))
              ((string-search " " val)))
        `(,(car args) display ,(string-replace " " "\u00a0" val))
      args))
  ;; HACK: `whitespace-mode' inundates child frames with whitespace markers, so
  ;;   disable it to fix all that visual noise.
  (defun my-whitespace--in-parent-frame-p () (null (frame-parameter nil 'parent-frame)))
  (add-function :before-while whitespace-enable-predicate #'my-whitespace--in-parent-frame-p))

(use-package indent-bars
  :hook ((emacs-lisp-mode
          simpc-mode
          sh-mode
          c-mode c-ts-mode
          c++-mode c++-ts-mode
          js-mode js-json-mode json-ts-mode
          typescript-ts-mode tsx-ts-mode)
         . indent-bars-mode)
  :custom
  (indent-bars-display-on-blank-lines nil)
  (indent-bars-width-frac 0.1)
  (indent-bars-color '(highlight :blend 0.4))
  (indent-bars-zigzag nil)
  (indent-bars-highlight-current-depth nil)
  (indent-bars-pattern "|"))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package colorful-mode
  :hook (prog-mode . colorful-mode)
  :custom
  (colorful-use-prefix t)
  ;; (colorful-prefix-string "■")
  (colorful-only-strings 'only-prog)
  (css-fontify-colors nil)
  :config
  (add-to-list 'global-colorful-modes 'helpful-mode)

  (define-advice colorful--colorize-match (:around (orig-func color beg end kind face map) my-box-face)
    (funcall orig-func color beg end kind (append face '(:height 0.90)) map)))

(use-package material-icon
:ensure nil                        ; 手动安装到 elpa/
:hook ((dired-mode . material-icon-dired-icons-mode)
(ibuffer-mode . material-icon-ibuffer-icons-mode))
:init
(setq material-icon-size 22)
(with-eval-after-load 'speedbar
(material-icon-speedbar-icons-mode 1)))

(use-package nerd-icons
  :commands
  (nerd-icons-octicon
   nerd-icons-faicon
   nerd-icons-flicon
   nerd-icons-wicon
   nerd-icons-mdicon
   nerd-icons-codicon
   nerd-icons-devicon
   nerd-icons-ipsicon
   nerd-icons-pomicon
   nerd-icons-powerline)
  :config
  (when (display-graphic-p)
    (unless (find-font (font-spec :name "Symbols Nerd Font Mono"))
      (nerd-icons-install-fonts t))))

(use-package nerd-icons-corfu
  :if (eq nn-completion-style 'corfu)
  :after corfu
  :init
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)
  (setq
   nerd-icons-corfu-mapping
   `((array :style "cod" :icon "symbol_array" :face nerd-icons-lblue)
     (boolean :style "cod" :icon "symbol_boolean" :face nerd-icons-lcyan)
     (class :style "cod" :icon "symbol_class" :face nerd-icons-lorange)
     (color :style "cod" :icon "symbol_color" :face nerd-icons-lorange)
     (command :style "cod" :icon "terminal" :face nerd-icons-purple)
     (constant :style "cod" :icon "symbol_constant" :face nerd-icons-lsilver)
     (constructor :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (enummember :style "cod" :icon "symbol_enum_member" :face nerd-icons-lblue)
     (enum-member :style "cod" :icon "symbol_enum_member" :face nerd-icons-lblue)
     (enum :style "cod" :icon "symbol_enum" :face nerd-icons-lyellow)
     (event :style "cod" :icon "symbol_event" :face nerd-icons-lorange)
     (field :style "cod" :icon "symbol_field" :face nerd-icons-lblue)
     (file :style "cod" :icon "file" :face nerd-icons-lsilver)
     (folder :style "cod" :icon "folder" :face nerd-icons-lyellow)
     (interface :style "cod" :icon "symbol_interface" :face nerd-icons-lcyan)
     (keyword :style "cod" :icon "symbol_keyword" :face nerd-icons-lblue)
     (macro :style "cod" :icon "symbol_misc" :face nerd-icons-pink)
     (magic :style "cod" :icon "wand" :face nerd-icons-purple)
     (method :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (function :style "cod" :icon "symbol_method" :face nerd-icons-purple)
     (module :style "cod" :icon "json" :face nerd-icons-lyellow)
     (numeric :style "cod" :icon "symbol_numeric" :face nerd-icons-lcyan)
     (operator :style "cod" :icon "symbol_operator" :face nerd-icons-lblue)
     (param :style "cod" :icon "symbol_parameter" :face nerd-icons-lsilver)
     (property :style "cod" :icon "symbol_property" :face nerd-icons-lblue)
     (reference :style "cod" :icon "references" :face nerd-icons-lblue)
     (snippet :style "cod" :icon "symbol_snippet" :face nerd-icons-lgreen)
     (string :style "cod" :icon "symbol_string" :face nerd-icons-lmaroon)
     (struct :style "cod" :icon "symbol_structure" :face nerd-icons-lorange)
     (text :style "cod" :icon "text_size" :face nerd-icons-lsilver)
     (typeparameter :style "cod" :icon "list_unordered" :face nerd-icons-lcyan)
     (type-parameter :style "cod" :icon "list_unordered" :face nerd-icons-lcyan)
     (unit :style "cod" :icon "symbol_ruler" :face nerd-icons-lsilver)
     (value :style "cod" :icon "symbol_field" :face nerd-icons-lblue)
     (variable :style "cod" :icon "symbol_variable" :face nerd-icons-lblue))))

(provide 'init-display)
