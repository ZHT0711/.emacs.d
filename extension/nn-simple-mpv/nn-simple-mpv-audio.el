;;; nn-simple-mpv-audio.el --- Audio playback via mpv  -*- lexical-binding: t; -*-

;;; Commentary:

;; Audio playback commands using mpv.  Unlike the video module, audio
;; playback is designed to be embedded inside an Emacs buffer (e.g. a
;; mode-line progress indicator, playback controls in a tabbed interface).
;;
;; TODO: This is a stub — implementation pending.

;;; Code:

(require 'nn-simple-mpv-core)

;; TODO: Implement audio playback buffer with:
;;   - Embedded playback via mpv --no-video
;;   - Buffer-local process per playlist
;;   - Mode-line progress (IPC --input-ipc-server)
;;   - Tab-bar integration
;;   - Playlist management

(provide 'nn-simple-mpv-audio)
;;; nn-simple-mpv-audio.el ends here
