;; -*- lexical-binding: t; -*-

(set-face-attribute 'default nil :family "IBM Plex Mono" :height 180)

(set-fontset-font t 'han (font-spec :family "Microsoft YaHei"))

;; (set-face-attribute 'default     nil :family "JetBrains Mono" :height 160)
;; (set-face-attribute 'italic      nil :family "JetBrains Mono Italic")
;; (set-face-attribute 'bold        nil :family "JetBrains Mono Bold")
;; (set-face-attribute 'bold-italic nil :family "JetBrains Mono Bold Italic")
;; (dolist (chars '("::" "..." "->" "=>" "<=" ">=" "!==" "!=" "===" "=="))
;;   (set-char-table-range
;;    composition-function-table
;;    (aref chars 0)
;;    (nconc (char-table-range composition-function-table (aref chars 0))
;;           (list (vector (regexp-quote chars) 0 'font-shape-gstring)))))

(provide 'init-font)
