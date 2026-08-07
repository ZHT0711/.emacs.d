;;; -*- lexical-binding: t -*-
(use-package sh-script
  :ensure nil
  :config
  (add-to-list 'sh-imenu-generic-expression
               '(sh (nil "^\\s-*function\\s-+\\([[:alpha:]_-][[:alnum:]_-]*\\)\\s-*\\(?:()\\)?" 1)
                    (nil "^\\s-*\\([[:alpha:]_-][[:alnum:]_-]*\\)\\s-*()" 1))))

(use-package bat-mode
  :ensure nil)

(provide 'lang-shell)
