;;; -*- lexical-binding: t -*-
(setq auth-sources '("~/.authinfo")
      user-full-name "zhaoxianiu"
      user-mail-address "zhaoxianiu@qq.com")

(use-package goto-addr
  :ensure nil
  :hook
  (prog-mode . goto-address-mode)
  (text-mode . goto-address-mode))

(use-package tramp
  :ensure nil
  :custom
  (remote-file-name-inhibit-cache 60)
  (remote-file-name-inhibit-locks t)
  (remote-file-name-inhibit-auto-save-visited t)
  (tramp-copy-size-limit (* 1024 1024))
  (tramp-use-scp-direct-remote-copying t)
  (tramp-completion-reread-directory-timeout 60)
  :config
  (unless (eq system-type 'windows-nt)
    (setq tramp-default-method "ssh"))
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application tramp :protocol "scp")
   'remote-direct-async-process))

(use-package erc
  :ensure nil
  :defines erc-interpret-mirc-color erc-autojoin-channels-alist
  :custom
  (erc-interpret-mirc-color t)
  (erc-lurker-hide-list '("JOIN" "PART" "QUIT"))
  (erc-autojoin-channels-alist '(("freenode.net" "#emacs"))))

(use-package eww
  :ensure nil
  :custom (eww-search-prefix "https://lite.duckduckgo.com/lite/?q=")
  :config
  (add-to-list 'eww-url-transformers #'eww-remove-tracking)

  (define-advice eww (:around (fn &rest args) myeww-open-in-fullscreen)
    "Open EWW in fullscreen if called interactively."
    (if (called-interactively-p 'any)
        (let ((display-buffer-alist '(("\\*eww\\*" (display-buffer-full-frame)))))
          (apply fn args))
      (apply fn args)))

  (defun my-eww-page-title-or-url ()
    "Use page title as buffer name, fallback to URL."
    (let ((title (plist-get eww-data :title)))
      (format "*%s # eww*" (if (string-blank-p title)
                               (plist-get eww-data :url)
                             title))))

  (if (boundp 'eww-auto-rename-buffer)
      (setq eww-auto-rename-buffer #'my-eww-page-title-or-url)
    (defun my-eww--rename-buffer-h (&rest _)
      (rename-buffer (my-eww-page-title-or-url)))
    (add-hook 'eww-after-render-hook #'my-eww--rename-buffer-h)
    (advice-add 'eww-back-url :after #'my-eww--rename-buffer-h)
    (advice-add 'eww-forward-url :after #'my-eww--rename-buffer-h)))

(use-package newsticker
  :ensure nil
  :bind ("C-c n" . my-newsticker-show-news)
  :hook (newsticker-start . nn-proxy-enable)
  :custom
  (newsticker-retrieval-interval 0)
  (newsticker-automatically-mark-items-as-old nil)
  (newsticker-url-list-defaults nil)
  (newsticker-url-list
   '(("Xkcd" "https://xkcd.com/rss.xml")
     ("Sacha Chua" "https://sachachua.com/blog/category/emacs-news/feed/")
     ("Planet Emacslife" "https://planet.emacslife.com/atom.xml")
     ("Emacs TIL" "https://emacstil.com/feed.xml")
     ("60秒看世界" "https://60s.viki.moe/v2/60s/rss")))
  :config
  (keymap-set newsticker-treeview-mode-map "C-x k" #'newsticker-treeview-quit)
  (defun my-newsticker-show-news ()
    (interactive)
    (require 'newsticker)
    (cl-letf (((symbol-function 'newsticker-start) #'ignore))
      (newsticker-show-news))))

(use-package smtpmail
  :ensure nil
  :custom
  (send-mail-function 'smtpmail-send-it)
  (smtpmail-smtp-user user-mail-address)
  (smtpmail-smtp-server "smtp.qq.com")
  (smtpmail-smtp-service 465)
  (smtpmail-stream-type 'ssl)
  (smtpmail-debug-info t)
  (smtpmail-debug-verb t))

(use-package gnus
  :ensure nil
  :hook ((gnus-select-group-hook . gnus-group-set-timestamp)
         (gnus-mark-article-hook . gnus-summary-mark-unread-as-read))
  :config
  (setq mm-text-html-renderer 'shr
        nnmail-expiry-wait 'never
        nnmail-expiry-target "Deleted Messages"
        gnus-blocked-images "ads"
        gnus-summary-line-format "%U%R%z %I%(%[%4L: %-23,23f%]%) %s\n"
        gnus-group-line-format "%M%S%5y:%B%(%-40,40g%) %d\n"
        gnus-user-date-format-alist '((t . "%Y-%m-%d %H:%M"))
        gnus-visible-headers "^From:\\|^To:\\|^Cc:\\|^Subject:\\|^Date:\\|^Newsgroups:"
        gnus-always-read-dribble-file t
        gnus-auto-select-first nil
        gnus-auto-select-next nil
        gnus-asynchronous t
        gnus-use-cache 'passive
        gnus-use-trees nil
        gnus-use-full-window nil
        gnus-message-archive-group nil
        gnus-ignored-newsgroups "^to\\.\\|^[0-9. ]+\\( \\|$\\)"
        gnus-thread-sort-functions '((not gnus-thread-sort-by-number) gnus-thread-sort-by-score)
        gnus-async-prefetch-article-p (lambda (data)
                                        (and (gnus-data-unread-p data)
                                             (< (mail-header-lines (gnus-data-header data)) 100)))
        gnus-select-method
        '(nnimap "qq.com"
                 (nnimap-address "imap.qq.com")
                 (nnimap-inbox "INBOX")
                 (nnimap-expunge t)
                 (nnimap-server-port 993)
                 (nnimap-stream ssl))))

(provide 'init-www)
