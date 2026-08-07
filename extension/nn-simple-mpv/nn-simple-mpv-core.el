;;; nn-simple-mpv-core.el --- Core mpv process management  -*- lexical-binding: t; -*-

;;; Commentary:

;; Shared utilities for nn-simple-mpv: mpv executable detection, process
;; lifecycle management, and common helper functions.

;;; Code:

(defgroup nn-simple-mpv nil
  "Simple external mpv media player."
  :group 'multimedia
  :prefix "nn-simple-mpv-")

(defcustom nn-simple-mpv-executable (executable-find "mpv")
  "Path to the mpv executable."
  :type 'file
  :group 'nn-simple-mpv)

(defcustom nn-simple-mpv-extra-options '("--no-terminal" "--keep-open=yes")
  "Extra command-line options passed to every mpv invocation."
  :type '(repeat string)
  :group 'nn-simple-mpv)

(defvar nn-simple-mpv--process nil
  "Current mpv process object, or nil if no playback is active.")

(defvar nn-simple-mpv--process-file nil
  "File name or URL being played by the current process.")

(defun nn-simple-mpv--ensure-executable ()
  "Return mpv executable path or signal an error if not found."
  (or nn-simple-mpv-executable
      (user-error "mpv executable not found; set `nn-simple-mpv-executable'")))

(defun nn-simple-mpv--sentinel (process event)
  "Process sentinel for mpv PROCESS.
EVENT is the process state change string."
  (when (memq (process-status process) '(exit signal))
    (setq nn-simple-mpv--process nil
          nn-simple-mpv--process-file nil)))

(defun nn-simple-mpv-start (file &optional extra-args)
  "Start mpv playing FILE (local path or URL).
EXTRA-ARGS is an optional list of additional command-line arguments
inserted before FILE."
  (nn-simple-mpv--stop)
  (let* ((exe (nn-simple-mpv--ensure-executable))
         (args (append nn-simple-mpv-extra-options extra-args (list file)))
         (proc (apply #'start-process "nn-mpv" nil exe args)))
    (setq nn-simple-mpv--process proc
          nn-simple-mpv--process-file file)
    (set-process-sentinel proc #'nn-simple-mpv--sentinel)
    proc))

(defun nn-simple-mpv--stop ()
  "Kill the current mpv process, if any."
  (when (nn-simple-mpv--active-p)
    (kill-process nn-simple-mpv--process)
    (setq nn-simple-mpv--process nil
          nn-simple-mpv--process-file nil)))

(defun nn-simple-mpv--active-p ()
  "Return non-nil if a mpv process is currently running."
  (and nn-simple-mpv--process
       (process-live-p nn-simple-mpv--process)))

(provide 'nn-simple-mpv-core)
;;; nn-simple-mpv-core.el ends here
