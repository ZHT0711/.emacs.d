;;; simple-mpv.el --- Simple mpv media player  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  zdn

;; Author: zdn
;; Keywords: multimedia, video, audio, mpv
;; URL: https://github.com/zdn/.emacs.d

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Minimal Emacs interface for the mpv media player.  Provides:
;;
;; * Video playback in an external window (simple-mpv-video)
;; * Audio playback with embedded Emacs UI (simple-mpv-audio)
;; * Shared process and configuration management (simple-mpv-core)
;;
;; Usage:
;;
;;   M-x simple-mpv-play-file  — play a local video file
;;   M-x simple-mpv-play-url   — stream a URL
;;   M-x simple-mpv-stop       — stop playback
;;
;; All public commands are autoloaded.  Requiring this file loads the
;; entire simple-mpv feature.

;;; Code:

(require 'simple-mpv-core)
(require 'simple-mpv-video)
(require 'simple-mpv-audio)

(provide 'simple-mpv)
;;; simple-mpv.el ends here
