;;; -*- lexical-binding: t -*-

(defvar nn-display-frame-padding 10
  "Outer padding, in pixels, for graphical top-level frames.")
(defvar nn-display-line-spacing 2
  "Extra space, in pixels, between text lines in graphical Emacs.")

(defun nn-display-apply-padding (&optional frame)
  "Apply modest whitespace to graphical FRAME, leaving child borders alone."
  (let ((frame (or frame (selected-frame))))
    (when (and (display-graphic-p frame) (not (frame-parent frame)))
      (setq-default line-spacing nn-display-line-spacing)
      (set-frame-parameter frame 'internal-border-width nn-display-frame-padding))))

(add-hook 'after-make-frame-functions #'nn-display-apply-padding)
(dolist (frame (frame-list))
  (nn-display-apply-padding frame))

(use-package fringe
  :ensure nil
  :custom
  (fringe-mode '(16 . 16))
  (indicate-buffer-boundaries nil)
  (overflow-newline-into-fringe nil)
  :config (setq-default fringes-outside-margins t))

(use-package nn-fringe-scale
  :ensure nil
  :demand t
  :config (nn-fringe-scale-mode 1))

(use-package shr
  :ensure nil
  :custom
  (shr-use-fonts t)
  (shr-width 80)
  (shr-indentation 2)
  (shr-bullet "• ")
  (shr-cookie-policy nil)
  (shr-href-highlight t)
  (shr-image-animate t)
  (shr-inhibit-images t)
  (shr-table-corners ?┼)
  (shr-table-horizontal-line ?─)
  (shr-table-vertical-line ?│)
  (shr-color-visible-luminance-min 60)
  (shr-color-visible-distance-min 5))

(use-package tooltip
  :ensure nil
  :custom (tooltip-resize-echo-area t))

(use-package display-line-numbers
  :ensure nil
  :hook
  (prog-mode text-mode conf-mode)
  ((org-mode markdown-mode markdown-ts-mode) . (lambda () (display-line-numbers-mode -1)))
  :custom
  (display-line-numbers-grow-only t)
  (display-line-numbers-width 3)
  (display-line-numbers-widen t)
  :config
  (defun nn-display-apply-line-number-background (&rest _)
    "Highlight only the current line number, without changing its text color."
    (let ((background
           (if (and (memq 'catppuccin custom-enabled-themes)
                    (fboundp 'catppuccin-color))
               (catppuccin-color 'surface0)
             (face-background 'highlight nil t))))
      (set-face-attribute 'line-number-current-line nil
                          :background (if (and (stringp background)
                                               (color-defined-p background))
                                          background
                                        'unspecified))))
  (add-hook 'enable-theme-functions #'nn-display-apply-line-number-background)
  (add-hook 'disable-theme-functions #'nn-display-apply-line-number-background)
  (nn-display-apply-line-number-background))

(use-package paren
  :ensure nil
  :hook (prog-mode . show-paren-mode)
  :custom
  (show-paren-delay 0.1)
  (show-paren-highlight-openparen t)
  (show-paren-when-point-inside-paren t)
  (show-paren-when-point-in-periphery t)
  (show-paren-style 'parenthesis)
  (show-paren-context-when-offscreen 'overlay)
  (blink-matching-paren-highlight-offscreen t)
  :config
  (define-advice show-paren--show-context-in-overlay (:after (_text) no-box)
    (when show-paren--context-overlay
      (overlay-put show-paren--context-overlay
                   'face '(:inherit default :box nil :height 0.9)))))

(use-package whitespace
  :ensure nil
  :hook
  (before-save . delete-trailing-whitespace)
  ((emacs-lisp-mode
    simpc-mode c-mode c++-mode
    js-mode js-json-mode json-ts-mode
    typescript-ts-mode tsx-ts-mode
    web-mode sh-mode powershell-mode
    makefile-mode makefile-gmake-mode)
   . my-code-whitespace-mode)
  :custom
  (whitespace-line-column nil)
  (whitespace-style '(face indentation tabs tab-mark))
  (whitespace-display-mappings
   '((tab-mark ?\t [?→ ?\t])
     (space-mark ?\  [?·] [?.])))
  :config
  (defun my-code-whitespace-mode ()
    "Show tab markers in code without drawing a marker for every space."
    (setq-local whitespace-style '(face indentation tabs tab-mark))
    (whitespace-mode 1)
    ;; Space markers are created only for the currently selected region.
    (add-hook 'post-command-hook #'my-update-selected-space-markers nil t)
    (add-hook 'deactivate-mark-hook #'my-clear-selected-space-markers nil t))
  (defvar-local my-selected-space-marker-overlays nil)
  (defvar-local my-selected-space-marker-state nil)
  (defun my-clear-selected-space-markers ()
    "Remove temporary space markers from the current buffer."
    (mapc #'delete-overlay my-selected-space-marker-overlays)
    (setq my-selected-space-marker-overlays nil
          my-selected-space-marker-state nil))
  (defun my-update-selected-space-markers ()
    "Show dots only for spaces inside the active selected region."
    (let* ((active (and (use-region-p) mark-active))
           (beg (and active (region-beginning)))
           (end (and active (region-end)))
           (state (and active
                       (list beg end (buffer-chars-modified-tick)))))
      (unless (equal state my-selected-space-marker-state)
        (mapc #'delete-overlay my-selected-space-marker-overlays)
        (setq my-selected-space-marker-overlays nil
              my-selected-space-marker-state state)
        (when active
          (save-excursion
            (goto-char beg)
            (while (re-search-forward " +" end t)
              (let* ((match-beg (match-beginning 0))
                     (match-end (match-end 0))
                     (marker (make-overlay match-beg match-end nil nil t))
                     (dots (propertize
                            (make-string (- match-end match-beg) ?·)
                            'face 'whitespace-space)))
                (overlay-put marker 'display dots)
                (overlay-put marker 'evaporate t)
                (push marker my-selected-space-marker-overlays))))))))
  ;; HACK: Suppress display mapping marks in overlays.
  (set-face-attribute 'nobreak-space nil :underline nil)
  (define-advice overlay-put (:filter-args (args) nn-bypass-whitespace-display)
    (if-let* ((prop (nth 1 args))
              (val (nth 2 args))
              ((eq prop 'display))
              ((stringp val))
              ((string-search " " val)))
        `(,(car args) display ,(string-replace " " "\u00a0" val))
      args))
  ;; HACK: `whitespace-mode' inundates child frames with whitespace markers.
  (defun my-whitespace--in-parent-frame-p () (null (frame-parameter nil 'parent-frame)))
  (add-function :before-while whitespace-enable-predicate #'my-whitespace--in-parent-frame-p))

(use-package indent-bars
  :commands indent-bars-mode
  :bind ("C-c i" . my-toggle-indent-bars)
  :preface
  (defun my-toggle-indent-bars ()
    "Toggle the colored indentation guides."
    (interactive)
    (if (bound-and-true-p indent-bars-mode)
        (progn
          (indent-bars-mode -1)
          (message "Indentation guides off"))
      ;; indent-bars does not recognize simpc-mode's indentation setting.
      (when (derived-mode-p 'simpc-mode)
        (setq-local indent-bars-spacing-override simpc-indent-width))
      (indent-bars-mode 1)
      (message "Indentation guides on")))
  :custom
  ;; Character bars work reliably in both Windows GUI and terminal Emacs.
  ;; Emacs 30+ on Windows supports stipple bars; they are cheaper than
  ;; inserting a display character into every indentation column.
  (indent-bars-prefer-character nil)
  (indent-bars-starting-column 0)
  (indent-bars-display-on-blank-lines nil)
  (indent-bars-highlight-current-depth nil)
  (indent-bars-width-frac 0.2)
  (indent-bars-color '(rainbow-delimiters-depth-1-face))
  ;; Reuse the bracket faces exactly, without blending their colors.
  (indent-bars-color-by-depth
   '(:regexp "\\`rainbow-delimiters-depth-\\([0-9]+\\)-face\\'"
     :blend nil))
  (indent-bars-zigzag nil)
  (indent-bars-pattern "|"))

(use-package rainbow-delimiters
  :hook prog-mode)

(use-package olivetti
  :ensure nil
  :hook
  (gnus-article-mode
   eww-mode org-mode markdown-ts-mode))

(use-package minibuffer-frame
  ;; 默认关闭 minibuffer-frame-mode，需要时手动 M-x minibuffer-frame-mode 开启
  )

(use-package color-picker
  :vc (:url "https://github.com/zHaOdANiuu/color-picker.el" :rev :newest)
  :commands color-picker
  :custom (color-picker-scale 2.0))

(use-package colorful-mode
  :hook (prog-mode . colorful-mode)
  :custom
  (colorful-use-prefix t)
  (colorful-only-strings 'only-prog)
  :config
  (add-to-list 'global-colorful-modes 'helpful-mode)

  (with-eval-after-load 'web-mode
    (add-hook 'web-mode (lambda () (setq-local colorful-only-strings nil))))

  (when (display-graphic-p)
    (require 'svg)

    (defun my-colorful--svg-img (color)
      (let* ((sz (frame-char-width))
             (svg (svg-create sz sz)))
        (svg-node svg 'rect
                  :x 1 :y 1 :width  (- sz 2) :height (- sz 2)
                  :fill color :stroke "#ffffff" :stroke-width "1.5")
        (svg-image svg :ascent 'center)))

    (defvar-keymap my-colorful--color-picker-map
      "<mouse-1>"
      (lambda (event)
        (interactive "e")
        (let* ((pos (event-start event))
               (xy  (posn-x-y pos))
               (ov  (colorful--find-overlay (posn-point pos))))
          (when ov
            (color-picker
             :style 'simple :display 'frame
             :x (car xy) :y (cdr xy)
             :ok (lambda (picked)
                   (with-current-buffer (overlay-buffer ov)
                     (delete-region (overlay-start ov) (overlay-end ov))
                     (insert picked)))) ))))

    (defun colorful--colorize-match (color beg end kind face map)
      "Overlay match with a face from BEG to END.
The background uses COLOR color value.  The foreground is obtained
from `readable-foreground-color'."
      (let ((ov (make-overlay beg end)))
        (overlay-put ov 'colorful--overlay t)
        (overlay-put ov 'colorful--color-kind kind)
        (overlay-put ov 'colorful--color color)
        (overlay-put ov 'evaporate t)
        (overlay-put ov
                     'before-string
                     (propertize
                      " "
                      'display (my-colorful--svg-img color)
                      'keymap my-colorful--color-picker-map
                      'pointer 'hand))
        (overlay-put ov 'face nil)))))

(use-package material-icon
  :vc (:url "https://github.com/zHaOdANiuu/material-icon.el" :rev :newest)
  :hook
  (dired-mode . material-icon-dired-icons-mode)
  (ibuffer-mode . material-icon-ibuffer-icons-mode)
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
   nerd-icons-powerline))

(use-package nerd-icons-corfu
  :if (eq nn-completion-style 'corfu)
  :after corfu
  :config
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
