;;; init-wsl.el --- WSL integration -*- lexical-binding: t; -*-

(defvar my-wsl-p (string-match-p "WSL" (or operating-system-release ""))
  "Non-nil if running in WSL.")

;; --- TUI 鼠标支持 ---
(when my-wsl-p
  (xterm-mouse-mode +1))

;; --- 剪切板集成 ---
(when my-wsl-p
  (defun my-wsl-copy (beg end)
    "Copy region to Windows clipboard via clip.exe."
    (interactive "r")
    (let ((default-directory "/"))
      (shell-command-on-region beg end "clip.exe" " *wsl-copy*"))
    (deactivate-mark))

  (defun my-wsl-get-clipboard ()
    "Get text from Windows clipboard via powershell.exe."
    (let ((clipboard
           (let ((default-directory "/"))
             (shell-command-to-string
              "powershell.exe -command 'Get-Clipboard' 2>/dev/null"))))
      (setq clipboard (replace-regexp-in-string "\r" "" clipboard))
      (substring clipboard 0 -1)))

  (defun my-wsl-paste ()
    "Paste from Windows clipboard."
    (interactive)
    (insert (my-wsl-get-clipboard)))

  ;; M-w 自动同步到 Windows 剪切板
  (advice-add 'gui-select-text :before
              (lambda (text)
                (when select-enable-clipboard
                  (with-temp-buffer
                    (insert text)
                    (my-wsl-copy (point-min) (point-max)))))))

;; --- browse-url 支持 ---
(when my-wsl-p
  (setenv "DISPLAY" ":0"))

;; --- 用 Windows 默认程序打开文件/目录（不依赖 wslu）---
(when my-wsl-p
  (with-eval-after-load 'dired
    (setq dired-guess-shell-alist-user
          '(("\\.pdf\\'" "cmd.exe /c start ''")
            ("\\.png\\'" "cmd.exe /c start ''")
            ("\\.jpg\\'" "cmd.exe /c start ''"))))

  (defun my-open-directory-here ()
    "Open current directory in Windows Explorer."
    (interactive)
    (shell-command
     (format "explorer.exe %s"
             (shell-quote-argument
              (replace-regexp-in-string "/" "\\\\"
                                        (expand-file-name default-directory))))))

  (global-set-key (kbd "C-c d") #'my-open-directory-here))

(provide 'init-wsl)
;;; init-wsl.el ends here
