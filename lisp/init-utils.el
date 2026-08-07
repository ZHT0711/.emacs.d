;;; -*- lexical-binding: t -*-
(use-package proced
  :ensure nil
  :init
  (setq-default proced-format 'verbose)
  :custom
  (proced-auto-update-flag t)
  (proced-auto-update-interval 3)
  (proced-enable-color-flag t))

(use-package webjump
  :ensure nil
  :bind ("C-c /" . webjump)
  :custom (webjump-sites
           '(("Emacs Home Page" .  "www.gnu.org/software/emacs/emacs.html")
             ("Xah Emacs Site" . "ergoemacs.org/index.html")
             ("(or emacs irrelevant)" . "oremacs.com")
             ("Mastering Emacs" . "https://www.masteringemacs.org/")
             ("DuckDuckGo" .
              [simple-query "duckduckgo.com"
                            "duckduckgo.com/?q=" ""])
             ("Google" .
              [simple-query "www.google.com"
                            "www.google.com/search?q=" ""])
             ("Bing" .
              [simple-query "www.bing.com"
                            "www.bing.com/search?q=" ""])
             ("Baidu" .
              [simple-query "www.baidu.com"
                            "www.baidu.com/s?wd=" ""])
             ("Wikipedia" .
              [simple-query "wikipedia.org" "wikipedia.org/wiki/" ""]))))

(use-package grep
  :ensure nil
  :config
  (when (executable-find "rg")
    (grep-apply-setting
     'grep-command "rg --color=auto --null -nH --no-heading -e ")
    (grep-apply-setting
     'grep-template "rg --color=auto --null --no-heading -g '!*/' -e <R> <D>")
    (grep-apply-setting
     'grep-find-command '("rg --color=auto --null -nH --no-heading -e ''" . 38))
    (grep-apply-setting
     'grep-find-template "rg --color=auto --null -nH --no-heading -e <R> <D>")))

(use-package wgrep
  :bind (:map grep-mode-map ("e" . wgrep-change-to-wgrep-mode))
  :custom
  (wgrep-auto-save-buffer t)
  (wgrep-change-readonly-file t))

(use-package rg
  :commands rg
  :hook (rg-mode . (lambda () (setq-local compilation-insert-header-function #'ignore)))
  :bind (("C-c s"   . my-rg-current-dir-all)
         ("C-c C-s" . rg-menu)
         :map rg-global-map
         ("c" . rg-dwim-current-dir)
         ("f" . rg-dwim-current-file)
         ("m" . rg-menu))
  :custom (rg-keymap-prefix nil)
  :config
  (add-to-list 'rg-custom-type-aliases '("tmpl" . "*.tmpl"))

  (defun my-rg-current-dir-all (query)
    "Search QUERY in all files under current directory."
    (interactive "sSearch (all files): ")
    (rg query "*" default-directory)))

(use-package calfw
  :custom
  (calfw-fchar-junction ?╋)
  (calfw-fchar-vertical-line ?┃)
  (calfw-fchar-horizontal-line ?━)
  (calfw-fchar-left-junction ?┣)
  (calfw-fchar-right-junction ?┫)
  (calfw-fchar-top-junction ?┯)
  (calfw-fchar-top-left-corner ?┏)
  (calfw-fchar-top-right-corner ?┓)
  (calfw-show-holidays nil))

(use-package calfw-org
  :commands calfw-org-open-calendar
  :bind ("C-c C-c" . my-calfw-open)
  :config
  (defun my-calfw-open ()
    (interactive)
    (calfw-org-open-calendar)
    (text-scale-set -2)
    (calfw-refresh-calendar-buffer)))

(use-package gt
  :bind
  (("C-c t w" . my-translate-word)
   ("C-c t r" . my-translate-region)
   ("C-c t b" . my-translate-buffer))
  :custom
  (gt-default-translator
   (gt-translator
    :taker (gt-taker :langs '(en zh) :text 'word :prompt t)
    :engines (list (gt-youdao-dict-engine)
                   (gt-youdao-suggest-engine))
    :render (gt-buffer-render)))
  :custom-face
  (gt-overlay-source-face ((t nil)))
  :config
  (defvar my-gt--active nil)

  (defun my-gt-translate (&optional mode)
    (let ((gt-polyglot-p t))
      (gt-start
       (gt-translator
        :taker (gt-taker :langs '(en zh) :text mode)
        :engines (list (if (eq mode 'word)
                           (gt-youdao-dict-engine)
                         (gt-bing-engine)))
        :render (if (eq mode 'word)
                    (gt-buffer-render)
                  (gt-overlay-render))))))

  (defun my-gt-clear ()
    (dolist (ov (gt-overlay-render-get-overlays (point-min) (point-max)))
      (delete-overlay ov)))

  (defun my-gt-auto-translate (&optional mode)
    (setq my-gt--active (not my-gt--active))
    (if my-gt--active
        (my-gt-translate mode)
      (my-gt-clear)))

  (defun my-translate-word   () (interactive) (my-gt-auto-translate 'word))
  (defun my-translate-region () (interactive) (my-gt-auto-translate 'region))
  (defun my-translate-buffer () (interactive) (my-gt-auto-translate 'buffer)))

(provide 'init-utils)
