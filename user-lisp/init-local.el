;;; init-local.el --- Personal commands and preferences -*- lexical-binding: t; -*-

;; 开启 delete-selection-mode：输入字符会替换选中区域
(delete-selection-mode 1)

;;在标题栏显示路径~
(setq frame-title-format
      '((:eval (if (buffer-file-name)
                   (abbreviate-file-name (buffer-file-name))
                 "%b"))))

;;This is a little shortcut for me to open the file
(defun my-smart-find-file ()
  "有选区时用选区内容打开文件，否则使用 `find-file-at-point'。"
  (interactive)
  (if (use-region-p)
      (let ((file (buffer-substring-no-properties
                   (region-beginning) (region-end))))
        (find-file file))
    (call-interactively 'find-file-at-point)))
(global-set-key (kbd "C-x C-f") 'my-smart-find-file)

;;using C-c e to add cursor
(global-set-key (kbd "C-c e") 'mc/edit-lines)

;; 设置为相对行号模式
(setq display-line-numbers-type 'relative)

;; 让当前行显示绝对行号（而不是0）
(setq display-line-numbers-current-absolute t)

;; ============================================================
;;  C-;  : 切换 // 行注释（逐行）
;;  M-;  : 切换 /* */ 块注释（无星号）
;; ============================================================



(defun my-c++-comment-star ()
  "切换 /* */ 块注释（无星号）。已注释则取消，否则添加。"
  (interactive)
  (if (use-region-p)
      (let* ((beg (region-beginning))
             (end (region-end))
             ;; 只计算一次非空首尾位置
             (first (save-excursion
                      (goto-char beg)
                      (skip-chars-forward " \t\n")
                      (point)))
             (last  (save-excursion
                      (goto-char end)
                      (skip-chars-backward " \t\n")
                      (point))))
        ;; 用字符比较检测是否已被 /* 和 */ 包裹
        (if (and (>= (- last first) 4)       ; 至少 /*x*/ 的长度
                 (eql (char-after first) ?/)
                 (eql (char-after (1+ first)) ?*)
                 (eql (char-after (- last 2)) ?*)
                 (eql (char-after (1- last)) ?/))
            ;; 已注释 -> 取消
            (progn
              (goto-char last)
              (delete-region (- last 2) last)  ; 删除 */
              (goto-char first)
              ;; 删除头部的 /* 或 /*
              (if (eql (char-after (+ first 2)) ?\s)
                  (delete-region first (+ first 3))
                (delete-region first (+ first 2))))
          ;; 未注释 -> 添加
          (progn
            (goto-char end)
            (insert " */")
            (goto-char beg)
            (insert "/* "))))
    ;; 没有选中区域：插入空块
    (insert "/*  */")
    (backward-char 3)))

(defun my-c/c++-mode-common-setup ()
  (local-set-key (kbd "C-;") 'comment-dwim)
  (local-set-key (kbd "M-;") 'my-c++-comment-star))

(add-hook 'c++-mode-hook 'my-c/c++-mode-common-setup)
(add-hook 'simpc-mode-hook 'my-c/c++-mode-common-setup)

;; 使用 Ctrl+Shift+鼠标左键 来添加或移除光标
(global-set-key (kbd "C-S-<mouse-1>") 'mc/add-cursor-on-click)

(require 'multiple-cursors)
(defun mc/toggle-cursor-at-point ()
  "在光标位置添加或移除一个光标。"
  (interactive)
  (if multiple-cursors-mode
      (message "Cannot toggle cursor at point while `multiple-cursors-mode' is active.")
    (let ((existing (mc/fake-cursor-at-point)))
      (if existing
          (mc/remove-fake-cursor existing)
        (mc/create-fake-cursor-at-point)))))
(add-to-list 'mc/cmds-to-run-once 'mc/toggle-cursor-at-point)
(global-set-key (kbd "C-M-<") 'mc/toggle-cursor-at-point) ; 绑定到 Ctrl+Shift+,+Alt

;;C-x C-/使用vundo
(use-package vundo
  :bind ("C-x C-/" . vundo))



;; ;; === local preference: cursor stays still 6s, blinks only after 6s idle ===
;; (defvar my/blink-delay-seconds 5.5
;;   "连续无操作多少秒后,光标才开始闪烁。")

;; (defvar my/blink-idle-timer nil)

;; (defun my/blink-stop ()
;;   "输入后:让光标实心不闪,并重新开始 6 秒倒计时。"
;;   (when my/blink-idle-timer
;;     (cancel-timer my/blink-idle-timer))
;;   (when blink-cursor-mode
;;     (blink-cursor-mode -1))
;;   (setq my/blink-idle-timer
;;         (run-with-idle-timer my/blink-delay-seconds nil #'my/blink-start)))

;; (defun my/blink-start ()
;;   "空闲满 6 秒:开始让光标闪烁。"
;;   (unless blink-cursor-mode
;;     (blink-cursor-mode 1)))

;; ;; 每执行一个命令(按键、移动光标等)都会重置倒计时
;; (add-hook 'post-command-hook #'my/blink-stop)
;; ;; 启动时立即初始化,避免刚启动的头 6 秒内光标在闪
;; (my/blink-stop)
;; ;; === end cursor-blink delay ===

;;把menu-bar干掉
(setq menu-bar-mode nil)

;;把minibuffer也干掉（等neomacs的匹配）
(setq minibuffer-frame-mode nil)

;; === nn-world current-line number face override (local preference) ===
(defun my-nn-world-line-number-face ()
  "Pink background with deep-red text for the current line number."
  (when (member 'nn-world custom-enabled-themes)
    (set-face-attribute 'line-number-current-line nil
                        :foreground "#5a1d1d" :background "#f0b0e0")))
(add-hook 'after-load-theme-hook #'my-nn-world-line-number-face)
(my-nn-world-line-number-face)
;; === end nn-world line-number face override ===

;;以下改掉gptel的api的response地址
(setq gptel-backend
      (gptel-make-openai "DS" ; 后端名称，可自定义
        :host "api.deepseek.com"    ; 替换为你的 API 主机地址
        :endpoint "/chat/completions" ; 替换为你的 API 端点路径
        :stream t                    ; 是否启用流式传输
        :key 'gptel-api-key          ; 从 ~/.authinfo 读取（auth-source），不放明文
        :models '(deepseek-flash))) ; 可用的模型列表

;; gptel-model 默认值为 nil，不在上面的 :models 列表里，会导致每次请求前发出
;; "Preferred `gptel-model' \"nil\" not supported in \"DS\" ..." 警告（必须是符号，字符串会再触发一条警告）。
(setq gptel-model 'deepseek-v4-flash)

(setq default-process-coding-system '(utf-8-unix . utf-8-unix))

(provide 'init-local)
;;; init-local.el ends here
