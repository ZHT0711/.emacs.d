;;; nn-draw-input.el --- Draw IME composition string in buffer -*- lexical-binding: t; -*-
(defvar nn-draw-input--buf "")
(defvar nn-draw-input--overlay nil)
(defvar nn-draw-input--process nil)
(defconst nn-draw-input--dir (file-name-directory (locate-library "nn-draw-input")))

(defface nn-draw-input-composition-face
  '((t :underline (:style dots)))
  "Face for composition string.")

(defun nn-draw-input--update (comp)
  "Update overlay with COMP string."
  (if (string-empty-p comp)
      (when nn-draw-input--overlay
        (delete-overlay nn-draw-input--overlay)
        (setq nn-draw-input--overlay nil))
    (unless (and nn-draw-input--overlay (overlay-buffer nn-draw-input--overlay))
      (setq nn-draw-input--overlay (make-overlay (point) (point) nil t nil)))
    (when-let* ((ov nn-draw-input--overlay))
      (move-overlay ov (point) (point))
      (overlay-put ov 'after-string
                   (propertize comp 'face 'nn-draw-input-composition-face)))))

(defun nn-draw-input--filter (_proc data)
  "Process filter: split DATA by newlines, update overlay.
Accumulates partial lines in `nn-draw-input--buf' and calls
`nn-draw-input--update' for each complete line."
  (setq nn-draw-input--buf (concat nn-draw-input--buf data))
  (while-let ((pos (string-search "\n" nn-draw-input--buf)))
    (let ((msg (substring nn-draw-input--buf 0 pos)))
      (setq nn-draw-input--buf (substring nn-draw-input--buf (1+ pos)))
      (nn-draw-input--update msg))))

(defun nn-draw-input--sentinel (_proc event)
  "Clean up overlay and state when the pipe process dies."
  (when (string-match-p "deleted\\|exited\\|failed" event)
    (when nn-draw-input--overlay
      (delete-overlay nn-draw-input--overlay)
      (setq nn-draw-input--overlay nil))
    (setq nn-draw-input--process nil
          nn-draw-input--buf "")))

(defun nn-draw-input-auto-build ()
  (interactive)
  (let* ((default-directory nn-draw-input--dir))
    (unless (file-exists-p (expand-file-name "nn-draw-input-core.dll" nn-draw-input--dir))
      (shell-command
       (mapconcat #'identity
                  '("clang++" "-std=c++23" "-fno-rtti" "-fno-exceptions" "-O3"
                    "-shared" "nn-draw-input-core.cpp" "-o" "nn-draw-input-core.dll"
                    "-limm32")
                  " ")))
    (unless (file-exists-p (expand-file-name "nn-draw-input-relay.exe" nn-draw-input--dir))
      (shell-command
       (mapconcat #'identity
                  '("clang++" "-std=c++23" "-fno-rtti" "-fno-exceptions""-O3"
                    "nn-draw-input-relay.cpp" "-o" "nn-draw-input-relay.exe")
                  " ")))))

(defun nn-draw-input-enable (&optional frame)
  "Enable IME composition string drawing."
  (interactive)
  (unless  (nn-ime-begin (cl-parse-integer (frame-parameter frame 'window-id)))
    (error "nn-draw-input-enable: failed to begin IME"))
  (setq nn-draw-input--process
        (make-process
         :name "nn-draw-input"
         :buffer nil
         :command (list (expand-file-name "nn-draw-input-relay.exe" nn-draw-input--dir))
         :filter #'nn-draw-input--filter
         :sentinel #'nn-draw-input--sentinel))
  (message "nn-draw-input enabled"))

(defun nn-draw-input-disable ()
  "Disable IME composition string drawing."
  (interactive)
  (nn-ime-shutdown)
  (when nn-draw-input--process
    (delete-process nn-draw-input--process)
    (setq nn-draw-input--process nil))
  (when nn-draw-input--overlay
    (delete-overlay nn-draw-input--overlay)
    (setq nn-draw-input--overlay nil))
  (message "nn-draw-input disabled"))

(nn-draw-input-auto-build)
(module-load (expand-file-name "nn-draw-input-core.dll" (file-name-directory load-file-name)))

(provide 'nn-draw-input)
;;; nn-draw-input.el ends here
