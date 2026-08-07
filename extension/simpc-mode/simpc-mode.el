;;; simpc-mode.el --- Simple C mode -*- lexical-binding: t; -*-
(defvar simpc-indent-width 2)

(defvar simpc-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?# "." table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?& "." table)
    (modify-syntax-entry ?% "." table)
    table))

(defconst simpc-types
  '("char" "int" "long" "short" "void" "bool" "float" "double" "signed" "unsigned"
    "char16_t" "char32_t" "char8_t" "wchar_t"
    "int8_t" "uint8_t" "int16_t" "uint16_t"
    "int32_t" "uint32_t" "int64_t" "uint64_t"
    "uintptr_t" "size_t" "ptrdiff_t" "va_list"))

(defconst simpc-keywords
  '("module" "export" "import"
    "class" "struct" "union" "enum" "typedef" "using"
    "decltype" "sizeof" "alignas" "alignof" "typeid"
    "auto" "const" "constexpr" "consteval" "constinit" "volatile"
    "extern" "static" "thread_local" "register"
    "operator" "inline" "explicit" "virtual" "override" "noexcept"
    "public" "protected" "private" "final" "friend" "mutable"
    "new" "delete" "nullptr" "true" "false" "this"
    "template" "typename" "requires" "concept"
    "static_cast" "dynamic_cast" "const_cast" "reinterpret_cast"
    "if" "else" "switch" "case" "default"
    "while" "do" "for" "break" "continue"
    "goto" "return"
    "try" "catch" "throw"
    "co_await" "co_return" "co_yield"
    "and" "and_eq" "or" "or_eq" "not" "not_eq" "xor" "xor_eq"
    "bitand" "bitor" "compl"
    "namespace" "asm" "static_assert" "reflexpr" "synchronized" "atomic_cancel"
    "atomic_commit" "atomic_noexcept"))

(defconst simpc-font-lock-keywords
  `(("^# *\\(warn\\|error\\)" . font-lock-warning-face)
    ("^# *[#a-zA-Z0-9_]+" . font-lock-preprocessor-face)
    ("^# *include\\(?:_next\\)?\\s-+\\(\\(<\\|\"\\).*\\(>\\|\"\\)\\)" 1 font-lock-string-face)
    (,(regexp-opt simpc-types 'symbols) . font-lock-type-face)
    (,(regexp-opt simpc-keywords 'symbols) . font-lock-keyword-face)
    ("\\b\\([a-zA-Z_][a-zA-Z0-9_]*\\(::[a-zA-Z_][a-zA-Z0-9_]*\\)+\\)" 0 font-lock-type-face)
    ("\\<\\(?:enum\\|using\\|struct\\|class\\)\\s-+\\([a-zA-Z0-9_]+\\)" 1 font-lock-type-face)
    ("\\<typedef\\b\\s-+\\w+\\s-+\\(\\w+\\)\\s-*;" 1 font-lock-type-face)
    ("\\<typedef\\b[^}]*}\\s-+\\(\\w+\\)" 1 font-lock-type-face)
    ("\\b\\([a-zA-Z_][a-zA-Z0-9_]*\\)(" 1 font-lock-function-name-face t)
    (")\\s-*->\\s-*\\([a-zA-Z_][a-zA-Z0-9_]*\\)" 1 font-lock-type-face)
    ("\\b\\([a-zA-Z_][a-zA-Z0-9_]*\\)<[^<>]*\\(<[^<>]*>\\)*[^<>]*>" 1 font-lock-type-face)
    ("\\<\\([a-zA-Z_][a-zA-Z0-9_]*\\)[*& \t]+[a-zA-Z_][a-zA-Z0-9_]*\\b" 1 font-lock-type-face)
    ;; function pointer
    (")[ \t]*(" ("\\([a-zA-Z_][a-zA-Z0-9_]*\\)[*& \t]*[,)]" nil nil (1 font-lock-type-face)))))

(defun simpc--previous-non-empty-line ()
  (save-excursion
    (move-beginning-of-line nil)
    (unless (bobp)
      (forward-line -1)
      (let* ((trimmed (string-trim-right
                       (buffer-substring-no-properties
                        (line-beginning-position) (line-end-position)))))
        (while (and (not (bobp))
                    (string-empty-p trimmed))
          (forward-line -1)
          (setq trimmed (string-trim-right
                         (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position)))))
        (unless (string-empty-p trimmed)
          (cons trimmed (current-indentation)))))))

(defun simpc--desired-indentation ()
  "Calculate the desired indentation for the current line."
  (let ((prev (simpc--previous-non-empty-line)))
    (if (not prev)
        (current-indentation)
      (let* ((indent-len simpc-indent-width)
             (prev-line (string-trim-right (car prev)))
             (prev-indent (cdr prev))
             (cur-line (string-trim
                        (buffer-substring-no-properties
                         (line-beginning-position) (line-end-position))))
             (prev-opens (string-match-p "[({[]\\'" prev-line))
             (cur-closes (string-match-p "\\`[)}]" cur-line))
             (prev-colon (string-suffix-p ":" prev-line))
             (cur-colon (string-suffix-p ":" cur-line)))
        (cond
         ((and (or prev-opens prev-colon)
               (or cur-closes cur-colon))
          prev-indent)
         ((or prev-opens prev-colon)
          (+ prev-indent indent-len))
         ((or cur-closes cur-colon)
          (max (- prev-indent indent-len) 0))
         (t prev-indent))))))

(defun simpc-indent-line ()
  (interactive)
  (when (not (bobp))
    (let* ((desired-indentation
            (simpc--desired-indentation))
           (n (max (- (current-column) (current-indentation)) 0)))
      (indent-line-to desired-indentation)
      (forward-char n))))

(define-derived-mode simpc-mode prog-mode "Simple C"
  "Simple major mode for editing C files."
  :syntax-table simpc-mode-syntax-table
  (setq-local font-lock-defaults '(simpc-font-lock-keywords))
  (setq-local indent-line-function #'simpc-indent-line)
  (setq-local comment-start "// "))

(provide 'simpc-mode)
;;; simpc-mode.el ends here
