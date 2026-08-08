;;; simple-mpv-audio.el --- Audio player (entry)  -*- lexical-binding: t; -*-

;;; Commentary:

;; Entry point for the mpv audio player.  Loads the two layers:
;;
;; * simple-mpv-audio-bridge — playback engine: state, control API,
;;   mpv process + IPC management, music library.
;; * simple-mpv-audio-ui     — display: music browser and player panel.
;;
;; The bridge layer never references UI code; it signals state changes
;; through `simple-mpv-audio--refresh-hook', and the UI subscribes to
;; that hook.  Requiring this file provides both layers.

;;; Code:

(require 'simple-mpv-audio-bridge)
(require 'simple-mpv-audio-ui)

(provide 'simple-mpv-audio)
;;; simple-mpv-audio.el ends here
