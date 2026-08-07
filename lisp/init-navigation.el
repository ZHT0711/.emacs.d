;;; -*- lexical-binding: t -*-
(use-package xref
  :autoload xref-show-definitions-completing-read
  :bind (("M-g ." . xref-find-definitions)
         ("M-g ," . xref-go-back))
  :init
  (when (executable-find "rg")
    (setq xref-search-program 'ripgrep))
  :custom
  (xref-show-definitions-function #'xref-show-definitions-completing-read)
  (xref-show-xrefs-function #'xref-show-definitions-completing-read))

(use-package bookmark
  :ensure nil
  :config
  (define-advice bookmark-bmenu--revert (:override (&rest _) my)
    "Re-populate `tabulated-list-entries' with icons."
    (let (entries)
      (dolist (full-record (bookmark-maybe-sort-alist))
        (let* ((name (bookmark-name-from-full-record full-record))
               (annotation (bookmark-get-annotation full-record))
               (location (bookmark-location full-record))
               (file (file-name-nondirectory location))
               (type (let ((fmt "%-8.8s"))
                       (cond ((null location)
                              (propertize (format fmt "NOFILE") 'face 'warning))
                             ((file-remote-p location)
                              (propertize (format fmt "REMOTE") 'face 'mode-line-buffer-id))
                             ((not (file-exists-p location))
                              (propertize (format fmt "NOTFOUND") 'face 'error))
                             ((file-directory-p location)
                              (propertize (format fmt "DIRED") 'face 'warning))
                             (t (propertize (format fmt "FILE") 'face 'success)))))
               (icon  (when (icons-displayable-p)
                        (cond
                         ((file-remote-p location)
                          (nerd-icons-codicon "nf-cod-radio_tower"))
                         ((file-directory-p location)
                          (nerd-icons-icon-for-dir location))
                         ((not (string-empty-p file))
                          (nerd-icons-icon-for-file file))))))
          (push (list
                 full-record
                 `[,(if (and annotation (not (string-empty-p annotation))) "*" "")
                   ,icon
                   ,(propertize
                     name
                     'font-lock-face 'bookmark-menu-bookmark
                     'mouse-face 'highlight
                     'follow-link t
                     'help-echo "mouse-2: go to this bookmark in other window")
                   ,type
                   ,@(when bookmark-bmenu-toggle-filenames
                       (list (propertize location 'face 'completions-annotations)))])
                entries)))
      (tabulated-list-init-header)
      (setq tabulated-list-entries entries))
    (tabulated-list-print t))

  (define-derived-mode bookmark-bmenu-mode tabulated-list-mode "Bookmark Menu"
    (setq truncate-lines t
          buffer-read-only t
          tabulated-list-format
          `[("" 1)
            ("" ,(if (icons-displayable-p) 2 0))
            ("Bookmark" ,bookmark-bmenu-file-column bookmark-bmenu--name-predicate)
            ("Type" 9)
            ,@(when bookmark-bmenu-toggle-filenames
                '(("File" 0 bookmark-bmenu--file-predicate)))]
          tabulated-list-padding bookmark-bmenu-marks-width
          tabulated-list-sort-key '("Bookmark" . nil))
    (add-hook 'tabulated-list-revert-hook #'bookmark-bmenu--revert nil t)))

(use-package citre
  :bind
  (("<f12>" . citre-jump)
   ("S-<f12>" . citre-jump-to-reference)
   ("M-<f12>" . citre-peek)
   :map citre-peek-keymap
   ("q" . keyboard-quit))
  :init (require 'citre-config)
  :hook (prog-mode . citre-mode)
  :custom-face (citre-peek-border-face ((t :inherit font-lock-keyword-face :strike-through t :extend t)))
  :custom
  (citre-readtags-program "readtags")
  (citre-ctags-program "ctags")
  (citre-peek-fill-fringe nil)
  (citre-completion-case-sensitive t)
  (citre-imenu-create-tags-file-threshold (* 20 1024 1024))
  (citre-default-create-tags-file-location 'in-dir)
  (citre-edit-ctags-options-manually nil)
  (citre-auto-enable-citre-mode-backends-for-remote nil)
  :config
  (add-to-list 'completion-category-overrides '(citre (styles basic)))

  (defvar-local nn-citre-external-tags nil
    "List of external tags files queried when the project tags returns nothing.")

  (define-advice citre-tags-get-tags (:around (old-fn tagsfile &rest args) nn-ext)
    "Fall back to `nn-citre-external-tags' when project tags returns nothing."
    (or (apply old-fn tagsfile args)
        (cl-loop for f in nn-citre-external-tags
                 for ext = (expand-file-name f)
                 when (file-exists-p ext)
                 thereis (apply old-fn ext args))))

  ;; ctags ext-kind-full → nerd-icons-corfu key
  ;; Also handles single-letter kind fallback.
  (defconst nn-lsp-kind
    '(("function" "function") ("method" "method") ("procedure" "function")
      ("submethod" "method") ("subprogram" "function") ("subroutine" "function")
      ("prototype" "function") ("functor" "function") ("callback" "function")
      ("class" "class") ("struct" "struct") ("structure" "struct")
      ("union" "struct") ("record" "class") ("component" "class")
      ("object" "class") ("role" "class")
      ("interface" "interface") ("trait" "interface") ("protocol" "interface")
      ("annotation" "interface") ("implementation" "class")
      ("enum" "enum") ("enumerator" "enummember")
      ("variable" "variable") ("local" "variable") ("global" "variable")
      ("parameter" "variable") ("instance" "variable") ("macroparam" "variable")
      ("field" "field") ("member" "field") ("slot" "field")
      ("property" "property") ("attribute" "property")
      ("constant" "constant") ("const" "constant")
      ("module" "module") ("namespace" "module") ("package" "module")
      ("library" "module") ("using" "module")
      ("type" "typeparameter") ("template" "typeparameter") ("tparam" "typeparameter")
      ("generic" "typeparameter") ("typedef" "keyword") ("alias" "keyword")
      ("name" "keyword") ("define" "macro") ("macro" "macro")
      ("constructor" "constructor") ("destructor" "constructor")
      ("event" "event") ("signal" "event") ("handler" "event")
      ("file" "file") ("header" "file") ("script" "file")
      ("label" "keyword") ("anchor" "keyword") ("key" "keyword")
      ("operator" "operator") ("string" "string") ("number" "numeric")
      ("boolean" "boolean") ("array" "array") ("exception" "class")))

  (define-advice citre-capf--make-candidate (:filter-return (cand) nn-kind)
    "Rewrite citre-kind to nerd-icons-corfu-compatible key."
    (when-let* ((raw (citre-get-property 'kind cand))
                (mapped (cadr (assoc-string (symbol-name raw) nn-lsp-kind 'case-fold))))
      (citre-put-property cand 'kind (intern mapped)))
    cand))

(use-package imenu-list
  :bind ("C-'" . imenu-list-smart-toggle)
  :custom
  (imenu-list-auto-resize t)
  (imenu-list-auto-update nil)
  (imenu-list-focus-after-activation t))

(provide 'init-navigation)
