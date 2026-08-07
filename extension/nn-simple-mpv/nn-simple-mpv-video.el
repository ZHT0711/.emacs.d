;;; nn-simple-mpv-video.el --- Video playback via mpv  -*- lexical-binding: t; -*-

;;; Commentary:

;; Interactive commands for playing video files and URLs in an external mpv
;; window.  All playback is handled by mpv running as a subprocess; no
;; video UI is embedded inside Emacs.

;;; Code:

(require 'nn-simple-mpv-core)

(defcustom nn-simple-mpv-video-geometry "50%"
  "Window size limit for the mpv video window.
A percentage like \"50%%\" limits the window to half the screen
while preserving aspect ratio.  See mpv's --autofit option."
  :type 'string
  :group 'nn-simple-mpv)

(defun nn-simple-mpv--video-args ()
  "Return extra command-line arguments for video playback."
  (when nn-simple-mpv-video-geometry
    (list (format "--autofit=%s" nn-simple-mpv-video-geometry))))

;;;###autoload
(defun nn-simple-mpv-play-file (file)
  "Play FILE with mpv in an external window.
Interactively, prompt for a file using `read-file-name'."
  (interactive (list (read-file-name "Play with mpv: ")))
  (let ((display-name (file-name-nondirectory file)))
    (nn-simple-mpv-start (expand-file-name file)
                         (nn-simple-mpv--video-args))
    (message "mpv: playing %s" display-name)))

;;;###autoload
(defun nn-simple-mpv-play-url (url)
  "Play URL with mpv in an external window.
Interactively, read a URL string from the minibuffer."
  (interactive (list (read-string "Play URL with mpv: ")))
  (nn-simple-mpv-start url (nn-simple-mpv--video-args))
  (message "mpv: playing URL"))

;;;###autoload
(defun nn-simple-mpv-stop ()
  "Stop the current mpv playback."
  (interactive)
  (if (nn-simple-mpv--active-p)
      (progn
        (nn-simple-mpv--stop)
        (message "mpv: stopped"))
    (message "mpv: no active playback")))

(provide 'nn-simple-mpv-video)
;;; nn-simple-mpv-video.el ends here
