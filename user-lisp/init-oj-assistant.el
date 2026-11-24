;;; init-oj-assistant.el --- OJ Assistant integration -*- lexical-binding: t; coding: utf-8; -*-

(defvar oj-assistant-command-map)
(declare-function oj-assistant-maybe-enable "oj-assistant")

(let ((directory "E:/OJ-Assistant-Emacs"))
  (when (file-readable-p (expand-file-name "oj-assistant.el" directory))
    (add-to-list 'load-path directory)
    (require 'oj-assistant)
    (global-set-key (kbd "C-c j") oj-assistant-command-map)
    (with-eval-after-load 'which-key
      (which-key-add-key-based-replacements "C-c j" "OJ Assistant"))
    (add-hook 'find-file-hook #'oj-assistant-maybe-enable)))

(provide 'init-oj-assistant)
;;; init-oj-assistant.el ends here
