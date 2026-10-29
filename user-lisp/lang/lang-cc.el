;;; -*- lexical-binding: t -*-
(require 'init-c-toolchains)

(defun my-clangd-args (_interactive)
  "Use the installed clangd with both GCC and Clang drivers."
  (let ((drivers (delq nil (mapcar #'executable-find '("gcc" "g++" "clang" "clang++"))))
        (fallback-db (my-c-toolchain-update-clangd-db)))
    (append
     (list (or (executable-find "clangd") "clangd")
           "--clang-tidy"
           "--limit-results=15"
           "--header-insertion=never"
           "--background-index"
           "--pch-storage=memory"
           (concat "--query-driver=" (mapconcat #'identity drivers ",")))
     (when fallback-db (list (concat "--compile-commands-dir=" fallback-db))))))

(use-package simpc-mode
  :ensure nil
  :mode "\\.\\(c\\|h\\|cpp\\|hpp\\|cppm\\|ixx\\)\\'"
  :config
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 '((c-mode c-ts-mode c++-mode c++-ts-mode simpc-mode) . my-clangd-args))))

(provide 'lang-cc)
