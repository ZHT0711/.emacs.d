;;; init-imenu.el --- Imenu & symbol outline configuration -*- lexical-binding: t; -*-

;; --- consult (includes consult-imenu) ---
(use-package consult
  :bind
  ("M-g i" . consult-imenu)        ; 当前文件跳转到符号
  ("M-g I" . consult-imenu-multi)  ; 跨文件搜索符号
  )

;; --- imenu-list: 侧边栏显示 imenu ---
(use-package imenu-list
  :bind
  ("C-c l" . imenu-list-smart-toggle)
  :custom
  (imenu-list-focus-after-activation t)   ; 激活后自动聚焦到侧边栏
  (imenu-list-auto-resize nil)            ; 不自动调整窗口大小
  (imenu-list-size 0.25)                  ; 窗口宽度占比 25%
  (imenu-list-position 'left))            ; 显示在左侧

;; --- M-g o 切换大纲 ---
(defun my-symbols-outline-toggle ()
  "Toggle symbols-outline window."
  (interactive)
  (require 'symbols-outline)
  (if (get-buffer-window "*Outline*" t)
      (quit-windows-on "*Outline*")
    (symbols-outline-show)))

(global-set-key (kbd "M-g o") #'my-symbols-outline-toggle)

;; --- symbols-outline: VSCode 风格大纲 (手动安装到 lisp/) ---
(use-package symbols-outline
  :ensure nil                           ; 不从 MELPA 安装，使用本地 lisp/ 目录
  :custom
  (symbols-outline-window-position 'right)
  (symbols-outline-window-width 35)
  (symbols-outline-ignore-variable-symbols t)
  (symbols-outline-collapse-functions-on-startup t)
  (symbols-outline-ctags-executable
   (if (string-match-p "WSL" (or operating-system-release ""))
       "/usr/bin/ctags"
     (expand-file-name "bin/ctags.exe" user-emacs-directory)))
  (symbols-outline-use-nerd-icon-in-gui t)
  :config
  (require 'nerd-icons nil t)
  (when (featurep 'nerd-icons)
    (defun symbols-outline-nerd-icon-str (icon-name &rest args)
      "Use nerd-icons package for proper icon rendering."
      (let* ((face (plist-get args :face))
             (fg (and face (face-attribute face :foreground))))
        (nerd-icons-faicon "nf-fa-code"
                           :face (if fg `(:foreground ,fg) 'default))))))

(provide 'init-imenu)
;;; init-imenu.el ends here
