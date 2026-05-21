;; QQ邮箱

(setq auth-sources '("~/.authinfo")
      user-full-name "zhaoxianiu"
      user-mail-address "zhaoxianiu@qq.com")

(use-package ispell
  :defer t
  :custom
  (ispell-program-name "aspell")
  (ispell-local-dictionary "en_US")
  (ispell-extra-args '("--sug-mode=ultra" "--lang=en_US")))

(use-package message
  :defer t
  :custom
  (message-directory "~/.emacs.d/mail/")
  (message-auto-save-directory "~/.emacs.d/mail/drafts/"))

(use-package smtpmail
  :defer t
  :custom
  (send-mail-function 'smtpmail-send-it)
  (smtpmail-smtp-user user-mail-address)
  (smtpmail-smtp-server "smtp.qq.com")
  (smtpmail-smtp-service 465)
  (smtpmail-stream-type 'ssl)
  (smtpmail-debug-info t)
  (smtpmail-debug-verb t))

(use-package gnus
  :defer t
  :hook
  (gnus-select-group-hook . gnus-group-set-timestamp)
  (gnus-mark-article-hook . gnus-summary-mark-unread-as-read)
  :custom
  ;; 目录设置
  (gnus-home-directory "~/.emacs.d/gnus/")
  (gnus-directory "~/.emacs.d/gnus/")
  (gnus-startup-file "~/.emacs.d/gnus/.newsrc")
  (gnus-init-file "~/.emacs.d/gnus.el")
  (nndraft-directory "~/.emacs.d/gnus/drafts/")
  (gnus-agent-directory "~/.emacs.d/gnus/agent/")
  ;; 服务器
  (gnus-select-method
   '(nnimap "qq.com"
            (nnimap-address "imap.qq.com")
            (nnimap-inbox "INBOX")
            (nnimap-split-methods default)
            (nnimap-expunge t)
            (nnimap-server-port 993)
            (nnimap-stream ssl)))
  (gnus-secondary-select-methods
   '((nntp "news.gmane.io")))
  ;; 忽略的新闻组
  (gnus-ignored-newsgroups "^to\\.\\|^[0-9. ]+\\( \\|$\\)")
  ;; 显示设置
  (gnus-summary-line-format "%U%R%z %I%(%[%4L: %-23,23f%]%) %s\n")
  (gnus-group-line-format "%M%S%5y:%B%(%-40,40g%) %ud\n")
  (gnus-user-date-format-alist '((t . "%Y-%m-%d %H:%M")))
  (gnus-blocked-images "ads")
  (gnus-visible-headers "^From:\\|^To:\\|^Cc:\\|^Subject:\\|^Date:\\|^Newsgroups:")
  (mm-text-html-renderer 'shr)
  ;; 行为设置
  (gnus-always-read-dribble-file t)
  (gnus-auto-select-first nil)
  (gnus-auto-select-next nil)
  (gnus-asynchronous t)
  (gnus-use-cache 'passive)
  (gnus-use-trees nil)
  (gnus-use-full-window nil)
  (gnus-message-archive-group nil)
  ;; 过期设置
  (nnmail-expiry-wait 'never)
  (nnmail-expiry-target "Deleted Messages")
  :config
  ;; 延迟发送
  (gnus-delay-initialize)

  (defun gnus-user-format-function-d (headers)
    (let ((time (gnus-group-timestamp gnus-tmp-group)))
      (if time
          (format-time-string "%b %d  %H:%M" time)
        "")))

  ;; 排序
  (setq gnus-thread-sort-functions '((not gnus-thread-sort-by-number) gnus-thread-sort-by-score))

  ;; 异步预取短文章
  (defun my-async-short-unread-p (data)
    (and (gnus-data-unread-p data)
         (< (mail-header-lines (gnus-data-header data)) 100)))
  (setq gnus-async-prefetch-article-p #'my-async-short-unread-p)

  ;; 移除旧的 mark hook
  (remove-hook 'gnus-mark-article-hook
               'gnus-summary-mark-read-and-unread-as-read))

(provide 'init-www)
