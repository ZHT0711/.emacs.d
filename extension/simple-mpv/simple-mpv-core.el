;;; simple-mpv-core.el --- Core mpv process management  -*- lexical-binding: t; -*-

;;; Commentary:

;; Shared utilities for simple-mpv: mpv executable detection, process
;; lifecycle management, and common helper functions.

;;; Code:

(defgroup simple-mpv nil
  "Simple external mpv media player."
  :group 'multimedia
  :prefix "simple-mpv-")

(defcustom simple-mpv-executable (executable-find "mpv")
  "Path to the mpv executable."
  :type 'file
  :group 'simple-mpv)

(defcustom simple-mpv-extra-options '("--no-terminal" "--keep-open=yes")
  "Extra command-line options passed to every mpv invocation."
  :type '(repeat string)
  :group 'simple-mpv)

(defvar simple-mpv--process nil
  "Current mpv process object, or nil if no playback is active.")

(defvar simple-mpv--process-file nil
  "File name or URL being played by the current process.")

(defun simple-mpv--ensure-executable ()
  "Return mpv executable path or signal an error if not found."
  (or simple-mpv-executable
      (user-error "mpv executable not found; set `simple-mpv-executable'")))

(defun simple-mpv--sentinel (process event)
  "Process sentinel for mpv PROCESS.
EVENT is the process state change string."
  (when (memq (process-status process) '(exit signal))
    (setq simple-mpv--process nil
          simple-mpv--process-file nil)))

(defun simple-mpv-start (file &optional extra-args)
  "Start mpv playing FILE (local path or URL).
EXTRA-ARGS is an optional list of additional command-line arguments
inserted before FILE."
  (simple-mpv--stop)
  (let* ((exe (simple-mpv--ensure-executable))
         (args (append simple-mpv-extra-options extra-args (list file)))
         (proc (apply #'start-process "simple-mpv" nil exe args)))
    (setq simple-mpv--process proc
          simple-mpv--process-file file)
    (set-process-sentinel proc #'simple-mpv--sentinel)
    proc))

(defun simple-mpv--stop ()
  "Kill the current mpv process, if any."
  (when (simple-mpv--active-p)
    (kill-process simple-mpv--process)
    (setq simple-mpv--process nil
          simple-mpv--process-file nil)))

(defun simple-mpv--active-p ()
  "Return non-nil if a mpv process is currently running."
  (and simple-mpv--process
       (process-live-p simple-mpv--process)))

(provide 'simple-mpv-core)
;;; simple-mpv-core.el ends here
