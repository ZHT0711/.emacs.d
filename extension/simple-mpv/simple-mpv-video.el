;;; simple-mpv-video.el --- Video playback via mpv  -*- lexical-binding: t; -*-

;;; Commentary:

;; Interactive commands for playing video files and URLs in an external mpv
;; window.  All playback is handled by mpv running as a subprocess; no
;; video UI is embedded inside Emacs.

;;; Code:

(require 'simple-mpv-core)

(defcustom simple-mpv-video-geometry "50%"
  "Window size limit for the mpv video window.
A percentage like \"50%%\" limits the window to half the screen
while preserving aspect ratio.  See mpv's --autofit option."
  :type 'string
  :group 'simple-mpv)

(defun simple-mpv--video-args ()
  "Return extra command-line arguments for video playback."
  (when simple-mpv-video-geometry
    (list (format "--autofit=%s" simple-mpv-video-geometry))))

;;;###autoload
(defun simple-mpv-play-file (file)
  "Play FILE with mpv in an external window.
Interactively, prompt for a file using `read-file-name'."
  (interactive (list (read-file-name "Play with mpv: ")))
  (let ((display-name (file-name-nondirectory file)))
    (simple-mpv-start (expand-file-name file)
                         (simple-mpv--video-args))
    (message "mpv: playing %s" display-name)))

;;;###autoload
(defun simple-mpv-play-url (url)
  "Play URL with mpv in an external window.
Interactively, read a URL string from the minibuffer."
  (interactive (list (read-string "Play URL with mpv: ")))
  (simple-mpv-start url (simple-mpv--video-args))
  (message "mpv: playing URL"))

;;;###autoload
(defun simple-mpv-stop ()
  "Stop the current mpv playback."
  (interactive)
  (if (simple-mpv--active-p)
      (progn
        (simple-mpv--stop)
        (message "mpv: stopped"))
    (message "mpv: no active playback")))

(provide 'simple-mpv-video)
;;; simple-mpv-video.el ends here
