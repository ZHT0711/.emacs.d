;;; -*- lexical-binding: t; -*-

(defvar nn-context-menu-items
  '("NN Menu"
    ["Spell Check" ispell-buffer]
    "--"
    ["Align Region"               align]
    ["Indent Region"              indent-region]
    ["Comment Region"             comment-or-uncomment-region]
    ["Sort Lines"                 sort-lines]
    ["Delete Trailing Whitespace" delete-trailing-whitespace]
    "--"
    ["Open AI Chat"             gptel]
    ["Ask AI About Region"      gptel-send]
    ["AI Rewrite Region"        gptel-rewrite]
    ["Add Region to AI Context" gptel-add]
    ["Add Buffer to AI Context" gptel-context-add-file]
    ["Clear AI Context"         gptel-context-remove-all]
    "--"
    ["Git Status"          magit-status]
    ["Git Blame"           magit-blame-addition]
    ["Git Log"             magit-log-buffer-file]
    ["Git Stage File"      magit-stage-file]
    ["Git Unstage File"    magit-unstage-file]
    ["Git Diff"            magit-diff-buffer-file]
    ["Git Discard Changes" magit-discard]))

;; TODO
(defvar nn-dired-menu-items
  '("NN Dired Menu"
    ["New C File"             kill-buffer]
    ["New C++ File"           kill-buffer]
    ["New C++ Module"         kill-buffer]
    ["New C/C++ Project"      kill-buffer]
    ["New Cpp Module Project" kill-buffer]
    ["New Web Project"        kill-buffer]))

(defun nn-context-menu (event)
  "鼠标右键菜单"
  (interactive "e")
  (let ((menu (cond
               ((derived-mode-p 'dired-mode) nn-dired-menu-items)
               (t nn-context-menu-items))))
    (popup-menu menu event)))

(keymap-global-set "<mouse-3>" #'nn-context-menu)

(provide 'init-context-menu)
