;;; simple-mpv.el --- Simple mpv media player  -*- lexical-binding: t; -*-
(require 'cl-lib)

(defvar simple-mpv--process nil)

(defvar simple-mpv--bridge nil)

(defvar simple-mpv--audio-list nil)

(defvar simple-mpv--audio-play-flag nil)

(defvar simple-mpv--audio-list-buffer nil)

(defvar simple-mpv--audio-control-buffer nil)

(defvar-keymap simple-mpv--audio-list-map
  "q" #'delete-window
  "<return>" #'simple-mpv--audio-list-buffer-play)

(defgroup simple-mpv nil
  "Simple external mpv media player."
  :group 'multimedia
  :prefix "simple-mpv-")

(defcustom simple-mpv-debug t
  "Show mpv process buffer."
  :type 'boolean
  :group 'simple-mpv)

(defcustom simple-mpv-exe "mpv"
  "Path to the mpv executable."
  :type 'file
  :group 'simple-mpv)

(defcustom simple-mpv-call-extra-args
  '("--autofit=50%" "--no-terminal" "--keep-open=yes")
  "Extra command line arguments passed to mpv process."
  :type '(repeat string)
  :group 'simple-mpv)

(defcustom simple-mpv-audio-directory "~/Music"
  "Directory where audio files are stored."
  :type 'directory
  :group 'simple-mpv)

(defcustom simple-mpv-audio-ext-rg
  "\\.\\(mp3\\|wav\\|m4a\\|m4s\\|flac\\|aac\\|ogg\\|wma\\)$"
  "Regular expression matching audio file extensions."
  :type 'string
  :group 'simple-mpv)

(defcustom simple-mpv-audio-bridge-script
  (expand-file-name
   "simple-mpv-bridge.ps1"
   (file-name-directory load-file-name))
  "Path to the PowerShell bridge script for simple-mpv IPC."
  :type 'file
  :group 'simple-mpv)

(defun simple-mpv--call (args)
  (apply #'start-process
         "simple-mpv-call" "*simple-mpv-call*"
         simple-mpv-exe args))

(defun simple-mpv--ipc-begin ()
  (setq simple-mpv--process
        (apply
         #'make-process
         :coding '(utf-8-dos . gbk-dos)
         :name "simple-mpv-process"
         :command `(,simple-mpv-exe
                    "--pause"  "--loop-playlist"
                    ,@(unless simple-mpv-debug '("--no-terminal"))
                    "--input-ipc-server=simple-mpv"
                    ,@simple-mpv--audio-list)
         (when simple-mpv-debug
           '(:buffer "*Simple mpv process*"))))
  (setq simple-mpv--bridge
        (make-process
         :coding '(utf-8-dos . gbk-dos)
         :name "simple-mpv-bridge"
         :buffer "*Simple mpv bridge*"
         :command `("powershell" "-File" ,simple-mpv-audio-bridge-script))))

(defun simple-mpv--ipc-end ()
  (when simple-mpv--process
    (delete-process simple-mpv--process)
    (setq simple-mpv--process nil))
  (when simple-mpv--bridge
    (delete-process simple-mpv--bridge)
    (setq simple-mpv--bridge nil)))

(defun simple-mpv--ipc-write (&rest args)
  (process-send-string
   simple-mpv--bridge
   (concat (mapconcat (lambda (s) (concat "\"" s "\"")) args ",") "\n")))

(defun simple-mpv--ipc-read ()
  (accept-process-output simple-mpv--bridge 1)
  (with-current-buffer (process-buffer simple-mpv--bridge)
    (when (> (buffer-size) 0)
      (let ((reply (string-trim (buffer-string))))
        (erase-buffer)
        reply))))

(defun simple-mpv--ipc-query (&rest args)
  (when (process-live-p simple-mpv--process)
    (apply #'simple-mpv--ipc-write args)
    (simple-mpv--ipc-read)))

(defun simple-mpv--get-metadata (key)
  (when-let* ((reply (simple-mpv--ipc-query
                      "get_property" (format "metadata/%s" key))))
    (cdr (assq 'data (json-read-from-string reply)))))

(defun simple-mpv--get-playlist-index (filename)
  (when-let* ((reply (simple-mpv--ipc-query "get_property" "playlist"))
              (playlist (cdr (assq 'data (json-read-from-string reply)))))
    (cl-loop for entry across playlist
             for i from 0
             when (string-suffix-p (file-name-nondirectory filename)
                                   (or (cdr (assq 'filename entry)) ""))
             return i)))

(defun simple-mpv--audio-list-buffer-cleanup ()
  (simple-mpv--ipc-end)
  (kill-buffer (process-buffer simple-mpv--process))
  (kill-buffer (process-buffer simple-mpv--bridge))
  (kill-buffer simple-mpv--audio-control-buffer))

(defun simple-mpv--audio-list-buffer-refresh ()
  (with-current-buffer simple-mpv--audio-list-buffer
    (erase-buffer)
    (add-hook 'kill-buffer-hook #'simple-mpv--audio-list-buffer-cleanup nil t)
    (setq tabulated-list-format
          [("Idx" 4 t)
           ("Name" 40 t)
           ("Tag" 0 t)])
    (setq tabulated-list-entries
          (cl-loop for f in simple-mpv--audio-list
                   for i from 1
                   collect
                   (list f (vector (number-to-string i)
                                   (file-name-nondirectory
                                    (file-name-sans-extension f))
                                   (file-name-nondirectory f)))))
    (tabulated-list-init-header)
    (tabulated-list-print)
    (special-mode)
    (use-local-map simple-mpv--audio-list-map)))

(defun simple-mpv--audio-list-buffer-play ()
  (interactive)
  (simple-mpv--audio-control-buffer-show)
  (simple-mpv--ipc-write
   "set_property" "playlist-pos"
   (number-to-string (simple-mpv--get-playlist-index (tabulated-list-get-id))))
  (simple-mpv--audio-toggle-play))

(defun simple-mpv--audio-control-button (text help cmd scale)
  (propertize
   text
   'face `(:height ,scale)
   'mouse-face 'highlight
   'help-echo help
   'keymap (let ((map (make-sparse-keymap)))
             (keymap-set map "<mouse-1>" cmd)
             map)))

(defun simple-mpv--audio-control-buffer-refresh ()
  (with-current-buffer simple-mpv--audio-control-buffer
    (erase-buffer)
    (insert
     (concat
      (simple-mpv--audio-get-metadata "title") "-"
      (simple-mpv--audio-get-metadata "artist") " "))
    (let* ((buttons
            (concat
             (simple-mpv--audio-control-button
              "🙏" "random play" #'simple-mpv--audio-random 1.6)
             " "
             (simple-mpv--audio-control-button
              "👈" "last audio" #'simple-mpv--audio-last 1.6)
             " "
             (simple-mpv--audio-control-button
              "👌" "play/stop audio" #'simple-mpv--audio-control-toggle-play 3.0)
             " "
             (simple-mpv--audio-control-button
              "👉" "next audio" #'simple-mpv--audio-next 1.6)
             " "
             (simple-mpv--audio-control-button
              "🤏" "loop play" #'simple-mpv--audio-loop 1.6)))
           (btn-width (string-width buttons))
           (pad (max 0 (/ (- (window-width) btn-width) 2))))
      (insert (make-string pad ?\s) buttons " "))
    (special-mode)
    (put-text-property (point-min) (point-max)'pointer 'arrow)
    (setq-local cursor-type nil)))

(defun simple-mpv--audio-control-buffer-show ()
  (unless (buffer-live-p simple-mpv--audio-control-buffer)
    (setq simple-mpv--audio-control-buffer
          (get-buffer-create "*Simple mpv audio control*"))
    (simple-mpv--audio-control-buffer-refresh))
  (let ((existing-win (get-buffer-window simple-mpv--audio-control-buffer)))
    (if existing-win
        (select-window existing-win)
      (when-let* ((win (display-buffer-in-side-window
                        simple-mpv--audio-control-buffer
                        '((side . bottom) (slot . 0)))))
        (fit-window-to-buffer win)
        (set-window-parameter win 'window-size-fixed t)
        (set-window-parameter win 'no-other-window t)
        (set-window-parameter win 'no-delete-other-windows t)
        (window-preserve-size win t)))))

(defun simple-mpv--audio-control-toggle-play ()
  (interactive)
  ;; (setf (nth 4 mode-line-format) (if simple-mpv--audio-play-flag "👌" "✋"))
  (simple-mpv--audio-toggle-play))

(defun simple-mpv--audio-toggle-play ()
  (if simple-mpv--audio-play-flag
      (simple-mpv--ipc-write "set_property" "pause" "yes")
    (simple-mpv--ipc-write "set_property" "pause" "no"))
  (setq simple-mpv--audio-play-flag (not simple-mpv--audio-play-flag)))

(defun simple-mpv--audio-last ()
  (interactive)
  (simple-mpv--ipc-write "playlist-prev")
  (message "Playing previous track"))

(defun simple-mpv--audio-next ()
  (interactive)
  (simple-mpv--ipc-write "playlist-next")
  (message "Playing next track"))

(defun simple-mpv--audio-random ()
  (interactive)
  (simple-mpv--ipc-write "playlist-shuffle")
  (message "Playlist shuffled, playing from first track"))

(defun simple-mpv--audio-loop ()
  (interactive)
  (simple-mpv--ipc-write "cycle-values" "loop" "inf" "no")
  (message "Loop mode toggled"))

;;;###autoload
(defun simple-mpv-play-file (file)
  (interactive "fPlay with mpv: ")
  (simple-mpv--call (cons (w32-short-file-name file) simple-mpv-call-extra-args)))

;;;###autoload
(defun simple-mpv-audio-browse ()
  (interactive)
  (unless (buffer-live-p simple-mpv--audio-list-buffer)
    (setq simple-mpv--audio-list
          (mapcar #'expand-file-name
                  (directory-files-recursively
                   simple-mpv-audio-directory
                   simple-mpv-audio-ext-rg
                   nil nil 1)))
    (simple-mpv--ipc-begin)
    (setq simple-mpv--audio-list-buffer
          (get-buffer-create "*Simple mpv audio list*"))
    (simple-mpv--audio-list-buffer-refresh))
  (switch-to-buffer-other-window simple-mpv--audio-list-buffer))

(provide 'simple-mpv)
;;; simple-mpv.el ends here
