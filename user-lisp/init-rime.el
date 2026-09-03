;;; init-rime.el --- RIME Chinese input (GNU/Linux incl. WSL) -*- lexical-binding: t; -*-

;; RIME input method via the `rime' package (rime-emacs, needs librime).
;; Windows native Emacs has no system librime, so this module only activates
;; on GNU/Linux hosts (incl. WSL) where librime headers are installed
;; system-wide (e.g. apt install librime-dev librime1t64).

(when (and (eq system-type 'gnu/linux)
           (file-exists-p "/usr/include/rime_api.h"))
  (use-package rime
    :ensure t
    :defer t
    :custom
    (rime-user-data-dir (expand-file-name "rime" user-emacs-directory))
    (rime-share-data-dir "/usr/share/rime-data")
    ;; Posframe popup on GUI, minibuffer candidates in terminal (-nw).
    (rime-show-candidate (if (display-graphic-p) 'posframe 'minibuffer))
    :config
    (setq default-input-method "rime")))

;;; init-rime.el ends here
