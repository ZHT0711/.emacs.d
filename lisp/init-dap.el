;;; -*- lexical-binding: t; -*-

(use-package dape
  :ensure t
  :defer t
  :bind
  ("<f5>"    . dape)
  ("S-<f5>"  . dape-quit)
  ("<f9>"    . dape-breakpoint-toggle)
  ("<f10>"   . dape-next)
  ("<f11>"   . dape-step-in)
  ("S-<f11>" . dape-step-out)
  ("C-<f5>"  . dape-kill)
  :custom
  (dape-debug t)
  (dape-inlay-hints nil)
  (dape-repl-echo-shell-output t)
  (dape-buffer-window-arrangement 'right)
  (dape-cwd-function #'my-dape-cwd-function)
  :config
  ;; (dape-breakpoint-global-mode 1)
  ;; (dape-breakpoint-load)
  ;; (add-hook 'kill-emacs-hook #'dape-breakpoint-save)
  (setq dape-configs
        `((c-cpp-gdb
           modes (c-mode c++-mode c-ts-mode c++-ts-mode)
           command "gdb"
           command-args ("-i=dap")
           :type "gdb"
           :request "launch"
           :program dape-buffer-default
           :cwd dape-cwd
           :initCommands ("set charset UTF-8"))))

  (defun my-dape-cwd-function ()
    (or (when-let ((project (project-current)))
          (project-root project))
        (dape--default-cwd)))

  (remove-hook 'dape-on-start-hooks 'dape-repl)
  (add-hook 'dape-repl-mode-hook #'mode-line-invisible-mode))

(provide 'init-dap)
