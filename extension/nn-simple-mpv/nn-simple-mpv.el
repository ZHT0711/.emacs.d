;;; nn-simple-mpv.el --- Simple mpv media player  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  zdn

;; Author: zdn
;; Keywords: multimedia, video, audio, mpv
;; URL: https://github.com/zdn/.emacs.d

;; This file is NOT part of GNU Emacs.

;;; Commentary:

;; Minimal Emacs interface for the mpv media player.  Provides:
;;
;; * Video playback in an external window (nn-simple-mpv-video)
;; * Audio playback — embedded in Emacs (nn-simple-mpv-audio, WIP)
;; * Shared process and configuration management (nn-simple-mpv-core)
;;
;; Usage:
;;
;;   M-x nn-simple-mpv-play-file  — play a local video file
;;   M-x nn-simple-mpv-play-url   — stream a URL
;;   M-x nn-simple-mpv-stop       — stop playback
;;
;; All public commands are autoloaded.  Requiring this file loads the
;; entire nn-simple-mpv feature.

;;; Code:

(require 'nn-simple-mpv-core)
(require 'nn-simple-mpv-video)
(require 'nn-simple-mpv-audio)

(provide 'nn-simple-mpv)
;;; nn-simple-mpv.el ends here
