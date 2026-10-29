;;; init-theme.el --- Catppuccin color theme -*- lexical-binding: t; -*-

(use-package catppuccin-theme
  :ensure t
  :demand t
  :init
  ;; Other flavors: latte (light), frappe, and macchiato.
  (setq catppuccin-flavor 'mocha)
  :config
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme 'catppuccin t))

(provide 'init-theme)
;;; init-theme.el ends here
