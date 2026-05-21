;;; -*- lexical-binding: t; -*-

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . markdown-mode)
  :custom
  (markdown-list-indent-width 2)
  (markdown-italic-underscore t)
  (markdown-gfm-additional-languages '("sh"))
  (markdown-make-gfm-checkboxes-buttons t)
  (markdown-fontify-whole-heading-line t)
  (markdown-fontify-code-blocks-natively t))

;; (use-package markdown-ts-mode
;;   :defer t
;;   :commands (markdown-ts-mode)
;;   :init
;;   (let ((rev (if (< (treesit-library-abi-version) 15) "v0.4.1" "v0.5.3")))
;;     (setq treesit-language-source-alist
;;           `((markdown
;;              ,(format "https://github.com/tree-sitter-grammars/tree-sitter-markdown")
;;              ,rev
;;              "tree-sitter-markdown/src")
;;             (markdown-inline
;;              ,(format "https://github.com/tree-sitter-grammars/tree-sitter-markdown")
;;              ,rev
;;              "tree-sitter-markdown-inline/src")))))

(use-package treesit
  :when (and (fboundp 'treesit-available-p) (treesit-available-p))
  :defer t
  :custom
  (treesit-font-lock-level 3)
  :config
  ;; 清理 auto-mode-alist 和 interpreter-mode-alist 中的 *-ts-mode 条目
  ;; 这些模式每次激活时都会修改这两个 alist
  (dolist (sym '(auto-mode-alist interpreter-mode-alist))
    (set sym
         (cl-loop for (src . fn) in (symbol-value sym)
                  unless (and (functionp fn)
                              (string-match "-ts-mode\\(?:-maybe\\)?$" (symbol-name fn)))
                  collect (cons src fn))))

  (defvar my-treesit-mode-remappings
    '((python-mode . python-ts-mode)
      (c-mode . c-ts-mode)
      (c++-mode . c++-ts-mode)
      (csharp-mode . csharp-ts-mode)
      (go-mode . go-ts-mode)
      (javascript-mode . js-ts-mode)
      (typescript-mode . typescript-ts-mode)
      (css-mode . css-ts-mode)
      (json-mode . json-ts-mode)
      (bash-mode . bash-ts-mode)
      ;; (markdown-mode . markdown-ts-mode)
      (yaml-mode . yaml-ts-mode)))

  ;; "如果 ts-mode 可用且语法库已安装则返回 ts-mode，否则返回原 mode。"
  (defun my-treesit-maybe-remap (mode)
    (if-let* ((ts-mode (cdr (assq mode my-treesit-mode-remappings)))
              ((fboundp ts-mode))
              ((treesit-ready-p ts-mode 'quiet)))
        ts-mode
      mode))
  (when (boundp 'major-mode-remap-alist)
    (dolist (remap my-treesit-mode-remappings)
      (add-to-list 'major-mode-remap-alist remap)))

  (when (fboundp 'major-mode-remap)
    (advice-add 'major-mode-remap :filter-return #'my-treesit-maybe-remap))

  (setq auto-mode-alist
        (append
         '(("\\.js\\'" . js-ts-mode)
           ("\\.ts\\'" . typescript-ts-mode)
           ("\\.c\\'" . c-ts-mode)
           ("\\.h\\'" . c-ts-mode)
           ("\\.cc\\'" . c++-ts-mode)
           ("\\.cpp\\'" . c++-ts-mode)
           ("\\.hpp\\'" . c++-ts-mode)
           ("\\.cppm\\'" . c++-ts-mode)
           ("\\.ixx\\'" . c++-ts-mode))
         auto-mode-alist))

  (dolist (lang '(c cpp
                    ;; markdown
                    ;; markdown-inline
                    ))
    (unless (treesit-ready-p lang t)
      (treesit-install-language-grammar lang)))

  ;; 补充语法库源
  (dolist (map '((awk . ("https://github.com/Beaglefoot/tree-sitter-awk"))
                 (bibtex . ("https://github.com/latex-lsp/tree-sitter-bibtex"))
                 (blueprint . ("https://github.com/huanie/tree-sitter-blueprint"))
                 (commonlisp . ("https://github.com/tree-sitter-grammars/tree-sitter-commonlisp"))
                 (latex . ("https://github.com/latex-lsp/tree-sitter-latex"))
                 (make . ("https://github.com/tree-sitter-grammars/tree-sitter-make"))
                 (nu . ("https://github.com/nushell/tree-sitter-nu"))
                 (org . ("https://github.com/milisims/tree-sitter-org"))
                 (perl . ("https://github.com/ganezdragon/tree-sitter-perl"))
                 (proto . ("https://github.com/mitchellh/tree-sitter-proto"))
                 (r . ("https://github.com/r-lib/tree-sitter-r"))
                 (sql . ("https://github.com/DerekStride/tree-sitter-sql" "gh-pages"))
                 (surface . ("https://github.com/connorlay/tree-sitter-surface"))
                 (toml . ("https://github.com/tree-sitter/tree-sitter-toml"))
                 (typst . ("https://github.com/uben0/tree-sitter-typst" "master" "src"))
                 (verilog . ("https://github.com/gmlarumbe/tree-sitter-systemverilog"))
                 (vhdl . ("https://github.com/alemuller/tree-sitter-vhdl"))
                 (vue . ("https://github.com/tree-sitter-grammars/tree-sitter-vue"))
                 (wast . ("https://github.com/wasm-lsp/tree-sitter-wasm" nil "wast/src"))
                 (wat . ("https://github.com/wasm-lsp/tree-sitter-wasm" nil "wat/src"))
                 (wgsl . ("https://github.com/mehmetoguzderin/tree-sitter-wgsl"))))
    (cl-pushnew map treesit-language-source-alist :test #'equal :key #'car)))

(provide 'init-lang)
