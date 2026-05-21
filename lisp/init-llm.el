;;; -*- lexical-binding: t; -*-

(use-package gptel
  :ensure t
  :defer t
  :bind (("C-c a i" . gptel))
  :custom
  (gptel-log-level 'info)
  (gptel-display-buffer-action nil)
  (gptel-default-mode 'markdown-mode)
  (gptel-temperature 0.1)
  (gptel-curl-file-size-threshold 0)
  (gptel-model "deepseek-v4-flash")
  :config
  (gptel-make-openai "ChatGPT"
    :stream t
    :key (lambda () (auth-source-pick-first-password :host "api.openai.com")))
  (gptel-make-deepseek "DeepSeek"
    :stream t
    :key (lambda () (auth-source-pick-first-password :host "api.deepseek.com")))
  (gptel-make-anthropic "Claude"
    :stream t
    :key (lambda () (auth-source-pick-first-password :host "api.anthropic.com")))

  (setq gptel-backend (gptel-get-backend "DeepSeek"))

  (add-to-list 'display-buffer-alist
               `(,(lambda (bname _action)
                    (and (null gptel-display-buffer-action)
                         (with-current-buffer (get-buffer bname)
                           (bound-and-true-p gptel-mode))))
                 (display-buffer-in-side-window)
                 (side . right)
                 (slot . 0)
                 (window-width . 0.45)
                 (select . t))))

(provide 'init-llm)
