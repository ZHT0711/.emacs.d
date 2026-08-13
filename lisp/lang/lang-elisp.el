;;; -*- lexical-binding: t -*-
(use-package elisp-mode
  :ensure nil
  :custom
  (emacs-lisp-indent-offset 2)
  (lisp-indent-function #'my-lisp-indent-function)
  :config
  (defun my-lisp-indent-function (indent-point state)
    "See https://emacs.stackexchange.com/questions/10230/how-to-indent-keywords-aligned"
    (let ((normal-indent (current-column))
          (orig-point (point)))
      (goto-char (1+ (elt state 1)))
      (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
      (cond
       ((and (elt state 2)
             (or (not (looking-at "\\sw\\|\\s_"))
                 (looking-at ":")))
        (if (not (> (save-excursion (forward-line 1) (point))
                    calculate-lisp-indent-last-sexp))
            (progn (goto-char calculate-lisp-indent-last-sexp)
                   (beginning-of-line)
                   (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)))
        (backward-prefix-chars)
        (current-column))
       ((and (save-excursion
               (goto-char indent-point)
               (skip-syntax-forward " ")
               (not (looking-at ":")))
             (save-excursion
               (goto-char orig-point)
               (looking-at ":")))
        (save-excursion
          (goto-char (+ 2 (elt state 1)))
          (current-column)))
       (t
        (let ((function-name (buffer-substring (point) (progn (forward-sexp 1) (point))))
              method)
          (setq method (or (function-get (intern-soft function-name) 'lisp-indent-function)
                           (get (intern-soft function-name) 'lisp-indent-hook)))
          (cond ((or (eq method 'defun)
                     (and (null method)
                          (length> function-name 3)
                          (string-match "\\`def" function-name)))
                 (lisp-indent-defform state indent-point))
                ((integerp method)
                 (lisp-indent-specform method state indent-point normal-indent))
                (method
                 (funcall method indent-point state))))))))

  (define-advice elisp-get-var-docstring (:around (fn sym) my-emacs-lisp-append-value-to-eldoc-a)
    "Display variable value next to documentation in eldoc."
    (when-let* ((ret (funcall fn sym)))
      (if (boundp sym)
          (concat ret " "
                  (let* ((truncated " [...]")
                         (print-escape-newlines t)
                         (str (symbol-value sym))
                         (str (prin1-to-string str))
                         (limit (- (frame-width) (length ret) (length truncated) 1)))
                    (format (format "%%0.%ds%%s" (max limit 0))
                            (propertize str 'face 'warning)
                            (if (< (length str) limit) "" truncated))))
        ret))))

(use-package help-mode
  :ensure nil
  :hook (help-mode . cursor-sensor-mode)
  :bind
  (:map help-mode-map
   ("r" . my-remove-hook-at-point))
  :config
  (defun my-function-advices (function)
    "Return FUNCTION's advices."
    (let ((flist (indirect-function function)) advices)
      (while (advice--p flist)
        (setq advices `(,@advices ,(advice--car flist)))
        (setq flist (advice--cdr flist)))
      advices))

  (defun my-help--update ()
    "Update the help buffer."
    (if (eq major-mode 'helpful-mode)
        (helpful-update)
      (revert-buffer nil t)))

  (defun my-add-remove-advice-button (advice function)
    (when (and (functionp advice) (functionp function))
      (let ((inhibit-read-only t)
            (msg (format "Remove advice `%s'" advice)))
        (insert "\t")
        (insert-button
         "Remove"
         'face 'custom-button
         'cursor-sensor-functions `((lambda (&rest _) ,msg))
         'help-echo msg
         'action (lambda (_)
                   (when (yes-or-no-p msg)
                     (message "%s from function `%s'" msg function)
                     (advice-remove function advice)
                     (my-help--update)))
         'follow-link t))))

  (defun my-add-button-to-remove-advice (buffer-or-name function)
    "Add a button to remove advice."
    (with-current-buffer buffer-or-name
      (save-excursion
        (goto-char (point-min))
        (let ((ad-list (my-function-advices function)))
          (while (re-search-forward "^\\(?:This function has \\)?:[-a-z]+ advice: \\(.+\\)$" nil t)
            (let ((advice (car ad-list)))
              (my-add-remove-advice-button advice function)
              (setq ad-list (delq advice ad-list))))))))

  ;; Remove hooks
  (defun my-remove-hook-at-point ()
    "Remove the hook at the point in the *Help* buffer."
    (interactive)
    (unless (memq major-mode '(help-mode helpful-mode))
      (error "Only for help-mode or helpful-mode"))

    (let ((orig-point (point)))
      (save-excursion
        (when-let*
            ((hook (progn (goto-char (point-min)) (symbol-at-point)))
             (func (when (and
                          (or (re-search-forward (format "^Value:?[\s|\n]") nil t)
                              (goto-char orig-point))
                          (thing-at-point 'sexp))
                     (thing-at-point--end-of-sexp)
                     (backward-char 1)
                     (catch 'break
                       (while t
                         (condition-case _err
                             (backward-sexp)
                           (scan-error (throw 'break nil)))
                         (let ((bounds (bounds-of-thing-at-point 'sexp)))
                           (when (<= (car bounds) orig-point (cdr bounds))
                             (throw 'break (thing-at-point 'sexp)))))))))
          (when (yes-or-no-p (format "Remove %s from %s? " func hook))
            (remove-hook hook (intern func))
            (my-help--update))))))

  (define-advice describe-function-1 (:after (f) my-advice-remove-button)
    (my-add-button-to-remove-advice (help-buffer) f))

  (define-advice helpful-update (:after () my-advice-remove-button) ()
                 (when helpful--callable-p
                   (my-add-button-to-remove-advice (current-buffer) helpful--sym))))

(provide 'lang-elisp)
