;;; simple-mpv-audio-bridge.el --- Audio playback engine (API/bridge)  -*- lexical-binding: t; -*-

;;; Commentary:

;; Playback engine for the mpv audio player: state, the control API
;; (play / pause / seek / next / prev / shuffle / repeat), mpv process
;; + IPC management, and the music library (scanned one level deep:
;; files directly in `simple-mpv-audio-directory', plus each non-empty
;; immediate subdirectory as a browse group).
;;
;; This file contains no UI code.  When playback state changes it runs
;; `simple-mpv-audio--refresh-hook'; the display layer
;; (simple-mpv-audio-ui.el) subscribes to that hook.  The entry point
;; (simple-mpv-audio.el) requires both layers.

;;; Code:

(require 'simple-mpv-core)
(require 'json)
(require 'cl-lib)

;;; Customization

(defgroup simple-mpv-audio nil
  "Audio playback with embedded Emacs UI."
  :group 'simple-mpv
  :prefix "simple-mpv-audio-")

(defcustom simple-mpv-audio-directory
  (expand-file-name "Music" (or (getenv "USERPROFILE") "~"))
  "Directory to scan for music files.
Scanned one level deep: files directly in it, plus files in its
immediate subdirectories (each subdirectory becomes a browse group)."
  :type 'directory
  :group 'simple-mpv-audio)

(defcustom simple-mpv-audio-extensions
  '("mp3" "flac" "wav" "ogg" "m4a" "aac" "wma" "opus" "ape" "wv")
  "File extensions recognized as music files (case-insensitive)."
  :type '(repeat string)
  :group 'simple-mpv-audio)

(defcustom simple-mpv-audio-ipc-retries 30
  "Number of 50ms retries when connecting to mpv IPC."
  :type 'integer
  :group 'simple-mpv-audio)

;;; Playback state

(defconst simple-mpv-audio--dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing simple-mpv-audio-bridge.el.")

(defvar simple-mpv-audio--process nil
  "mpv audio subprocess (the mpv binary).")

(defvar simple-mpv-audio--connection nil
  "Network process for JSON IPC to mpv.")

(defvar simple-mpv-audio--playlist nil
  "List of absolute music file paths, in playback order.")

(defvar simple-mpv-audio--library nil
  "Grouped library for the browse view.
List of nodes in display order; each node is either
  (tracks FILE...)              — root-level files (rendered without a
                                  header)
  ((dir . NAME) (tracks FILE...)) — one subdirectory group
The tracks of all nodes, concatenated in order, equal
`simple-mpv-audio--playlist'.")

(defvar simple-mpv-audio--index 0
  "Current track position in the playback sequence.
When shuffle is active this is a position into
`simple-mpv-audio--shuffled'; otherwise a position into
`simple-mpv-audio--playlist'.")

(defvar simple-mpv-audio--paused nil)

(defvar simple-mpv-audio--duration 0.0)

(defvar simple-mpv-audio--position 0.0)

(defvar simple-mpv-audio--title "")

(defvar simple-mpv-audio--artist "")

(defvar simple-mpv-audio--repeat nil)

(defvar simple-mpv-audio--shuffle nil)

(defvar simple-mpv-audio--shuffled nil
  "Shuffled playlist indices (permutation of 0..n-1).")

(defvar simple-mpv-audio--timer nil
  "Progress update timer (0.5s tick), owned by the UI layer.
Declared here because the playback layer cancels it in
`simple-mpv-audio--kill-process'.")

(defvar simple-mpv-audio--request-id 0)

(defvar simple-mpv-audio--callbacks (make-hash-table :size 16))

(defvar simple-mpv-audio--line-buf "")

(defvar simple-mpv-audio--loading nil
  "Non-nil while a loadfile is in-flight (suppresses end-file handling).")

(defvar simple-mpv-audio--refresh-hook nil
  "Hook run by the playback layer after playback state changes.
The UI layer adds its renderers here; this hook is the only seam
between the two layers.")

(defun simple-mpv-audio--refresh-ui ()
  "Notify the UI that playback state changed."
  (run-hooks 'simple-mpv-audio--refresh-hook))

;;; Control API
;; The only places that mutate playback state.  The UI calls these
;; commands and reads the state vars; it never mutates state itself.

(defun simple-mpv-audio--set-paused (p)
  "Set the paused state to P (nil = playing, t = paused)."
  (simple-mpv-audio--ensure-process)
  (simple-mpv-audio--send-nowait `("set_property" "pause" ,p))
  (setq simple-mpv-audio--paused p)
  (simple-mpv-audio--refresh-ui))

(defun simple-mpv-audio-play ()
  "Resume playback."
  (interactive)
  (simple-mpv-audio--set-paused nil))

(defun simple-mpv-audio-pause ()
  "Pause playback."
  (interactive)
  (simple-mpv-audio--set-paused t))

(defun simple-mpv-audio-toggle-pause ()
  "Toggle between playing and paused."
  (interactive)
  (simple-mpv-audio--set-paused (not simple-mpv-audio--paused)))

(defun simple-mpv-audio--seek (delta)
  "Seek by DELTA seconds relative to the current position."
  (simple-mpv-audio--ensure-process)
  (simple-mpv-audio--send-nowait `("seek" ,delta "relative"))
  (let ((pos (+ (or simple-mpv-audio--position 0.0) delta)))
    (setq simple-mpv-audio--position (max 0.0 pos)))
  (simple-mpv-audio--refresh-ui))

(defun simple-mpv-audio-seek-forward ()
  "Seek forward 5 seconds."
  (interactive)
  (simple-mpv-audio--seek 5))

(defun simple-mpv-audio-seek-backward ()
  "Seek backward 5 seconds."
  (interactive)
  (simple-mpv-audio--seek -5))

(defun simple-mpv-audio-next ()
  "Skip to the next track."
  (interactive)
  (simple-mpv-audio--ensure-process)
  (unless simple-mpv-audio--playlist
    (user-error "Playlist is empty — run M-x simple-mpv-audio first"))
  (let ((len (length simple-mpv-audio--playlist)))
    (if (< (1+ simple-mpv-audio--index) len)
        (simple-mpv-audio--load (1+ simple-mpv-audio--index))
      (if (eq simple-mpv-audio--repeat 'all)
          (simple-mpv-audio--load 0)
        (message "simple-mpv-audio: end of playlist")))))

(defun simple-mpv-audio-prev ()
  "Go back to the previous track."
  (interactive)
  (simple-mpv-audio--ensure-process)
  (unless simple-mpv-audio--playlist
    (user-error "Playlist is empty — run M-x simple-mpv-audio first"))
  (if (> simple-mpv-audio--index 0)
      (simple-mpv-audio--load (1- simple-mpv-audio--index))
    (if (eq simple-mpv-audio--repeat 'all)
        (simple-mpv-audio--load (1- (length simple-mpv-audio--playlist)))
      (message "simple-mpv-audio: start of playlist"))))

(defun simple-mpv-audio-toggle-shuffle ()
  "Toggle shuffle playback.
The currently playing track stays current in both directions:
enabling shuffle remaps the index into the new shuffled order,
disabling it restores the index to the real playlist position."
  (interactive)
  (let ((cur (simple-mpv-audio--current-playlist-index)))
    (setq simple-mpv-audio--shuffle (not simple-mpv-audio--shuffle))
    (if simple-mpv-audio--shuffle
        (simple-mpv-audio--reshuffle cur)
      (setq simple-mpv-audio--index cur
            simple-mpv-audio--shuffled nil)))
  (simple-mpv-audio--refresh-ui))

(defun simple-mpv-audio-toggle-repeat ()
  "Cycle repeat mode: off -> all -> one -> off."
  (interactive)
  (setq simple-mpv-audio--repeat
        (pcase simple-mpv-audio--repeat
          ('nil 'all)
          ('all 'one)
          ('one nil)))
  (simple-mpv-audio--refresh-ui))

;;; mpv process / IPC

(defun simple-mpv-audio--ipc-name ()
  "Unique IPC identifier for the mpv pipe/socket."
  (format "simple-mpv-audio-%d" (emacs-pid)))

(defun simple-mpv-audio--ipc-port ()
  "Return a TCP port number for the IPC bridge, derived from Emacs PID."
  (+ 58000 (mod (emacs-pid) 1000)))

(defun simple-mpv-audio--mpv-ipc-arg ()
  "Return the --input-ipc-server argument for the mpv command line.
On Windows uses a named pipe; on Unix a Unix-domain socket."
  (let ((name (simple-mpv-audio--ipc-name)))
    (if (eq system-type 'windows-nt)
        (format "--input-ipc-server=%s" name)
      (let ((path (expand-file-name (format "%s.socket" name)
                                    temporary-file-directory)))
        (ignore-errors (delete-file path))
        (format "--input-ipc-server=%s" path)))))

(defvar simple-mpv-audio--bridge-process nil
  "Python bridge subprocess (Windows only).")

(defun simple-mpv-audio--bridge-script ()
  "Return the path of the standalone Python bridge script."
  (expand-file-name "simple-mpv-audio-bridge.py" simple-mpv-audio--dir))

(defun simple-mpv-audio--bridge-validate ()
  "Signal a user-error if the Windows IPC bridge cannot run."
  (unless (file-exists-p (simple-mpv-audio--bridge-script))
    (user-error "simple-mpv-audio: bridge script %s not found"
                (simple-mpv-audio--bridge-script)))
  (unless (executable-find "python")
    (user-error "simple-mpv-audio: Python not found — required for the Windows IPC bridge")))

(defun simple-mpv-audio--bridge-start ()
  "Start the named-pipe-to-TCP bridge (Windows only).
Runs the standalone Python script `simple-mpv-audio-bridge.py'
(native Win32) which relays between mpv's named pipe and TCP.
Call `simple-mpv-audio--bridge-validate' first."
  (make-process
   :name "simple-mpv-audio-bridge"
   :command (list "python"
                  (simple-mpv-audio--bridge-script)
                  (simple-mpv-audio--ipc-name)
                  (number-to-string (simple-mpv-audio--ipc-port)))
   :noquery t
   :connection-type 'pipe))

(defun simple-mpv-audio--ipc-connect ()
  "Open a connection to the mpv IPC.
On Windows uses TCP (via bridge); on Unix uses a Unix-domain socket."
  (ignore-errors
    (if (eq system-type 'windows-nt)
        (make-network-process
         :name "simple-mpv-audio-ipc"
         :family 'ipv4
         :host "127.0.0.1"
         :service (simple-mpv-audio--ipc-port)
         :coding 'utf-8
         :noquery t
         :filter #'simple-mpv-audio--ipc-filter
         :sentinel #'simple-mpv-audio--ipc-sentinel)
      (make-network-process
       :name "simple-mpv-audio-ipc"
       :family 'local
       :service (expand-file-name
                 (format "%s.socket" (simple-mpv-audio--ipc-name))
                 temporary-file-directory)
       :coding 'utf-8
       :noquery t
       :filter #'simple-mpv-audio--ipc-filter
       :sentinel #'simple-mpv-audio--ipc-sentinel))))

(defun simple-mpv-audio--ipc-connect-with-retry ()
  "Connect to mpv IPC, retrying with 50ms sleeps."
  (cl-loop repeat simple-mpv-audio-ipc-retries
           do (sleep-for 0.05)
           thereis (simple-mpv-audio--ipc-connect)))

(defun simple-mpv-audio--send (cmd &optional callback)
  "Encode CMD as JSON and send to mpv via IPC.
If CALLBACK is given, call it with the response data on success."
  (if (and simple-mpv-audio--connection
           (process-live-p simple-mpv-audio--connection))
      (progn
        (cl-incf simple-mpv-audio--request-id)
        (let* ((req-id simple-mpv-audio--request-id)
               (json-str (json-encode `((command . ,cmd)
                                        (request_id . ,req-id)))))
          (when callback
            (puthash req-id callback simple-mpv-audio--callbacks))
          (process-send-string simple-mpv-audio--connection
                               (concat json-str "\n"))))
    (message "simple-mpv-audio: not connected — run M-x simple-mpv-audio first")))

(defun simple-mpv-audio--send-nowait (cmd)
  "Send CMD to mpv without a callback."
  (simple-mpv-audio--send cmd nil))

(defun simple-mpv-audio--ipc-filter (_proc string)
  "Parse newline-delimited JSON from the mpv IPC connection."
  (setq simple-mpv-audio--line-buf
        (concat simple-mpv-audio--line-buf string))
  (while (string-match "\n" simple-mpv-audio--line-buf)
    (let* ((end (match-beginning 0))
           (raw (substring simple-mpv-audio--line-buf 0 end))
           (msg (json-parse-string
                 raw
                 :object-type 'alist
                 :array-type  'list
                 :null-object nil)))
      (setq simple-mpv-audio--line-buf
            (substring simple-mpv-audio--line-buf (match-end 0)))
      (when msg (simple-mpv-audio--dispatch msg)))))

(defun simple-mpv-audio--dispatch (msg)
  "Route a parsed JSON message from mpv."
  (let ((event (cdr (assq 'event msg)))
        (req-id (cdr (assq 'request_id msg)))
        (data   (cdr (assq 'data msg)))
        (error  (cdr (assq 'error msg))))
    (when req-id
      (let ((cb (gethash req-id simple-mpv-audio--callbacks)))
        (when cb
          (remhash req-id simple-mpv-audio--callbacks)
          (unless (equal error "success")
            (message "simple-mpv-audio: IPC error: %s" (or error "?")))
          (funcall cb data))))
    (cond ((equal event "property-change")
           (simple-mpv-audio--on-property (cdr (assq 'name msg)) data))
          ((equal event "end-file")
           (simple-mpv-audio--on-end-file (cdr (assq 'reason msg)))))))

(defun simple-mpv-audio--fetch-metadata ()
  "Fetch the current track's metadata from mpv."
  (simple-mpv-audio--send
   '("get_property" "metadata")
   (lambda (data)
     (simple-mpv-audio--set-metadata data)
     (simple-mpv-audio--refresh-ui))))

(defun simple-mpv-audio--on-property (name value)
  "Handle a property-change event from mpv."
  (pcase name
    ("time-pos"    (setq simple-mpv-audio--position (or value 0.0)))
    ("pause"       (setq simple-mpv-audio--paused (or value t)))
    ("duration"    (setq simple-mpv-audio--duration (or value 0.0)))
    ("media-title"
     (setq simple-mpv-audio--title
           (if value (file-name-sans-extension value) "")))
    ("metadata"    (simple-mpv-audio--set-metadata value))
    ;; A new file is fully loaded; fetch metadata now instead of
    ;; guessing a fixed delay after the loadfile ack.
    ("file-loaded" (when value (simple-mpv-audio--fetch-metadata))))
  (simple-mpv-audio--refresh-ui))

(defun simple-mpv-audio--observe-properties ()
  "Tell mpv to push change events for tracked properties."
  (dolist (prop '("time-pos" "pause" "duration" "media-title"
                  "metadata" "file-loaded" "eof-reached"))
    (simple-mpv-audio--send-nowait `("observe_property" 0 ,prop))))

(defun simple-mpv-audio--ipc-sentinel (proc _event)
  "Clean up when the IPC connection drops.
Only acts when PROC is still the current connection, so a sentinel
from a replaced connection cannot clobber a live one."
  (when (memq (process-status proc) '(exit signal closed))
    (when (eq proc simple-mpv-audio--connection)
      (setq simple-mpv-audio--connection nil)
      (message "simple-mpv-audio: IPC connection lost"))))

;;; mpv process lifecycle

(defun simple-mpv-audio--kill-process ()
  "Kill the mpv process, bridge, and IPC connection; cancel the timer.
Does NOT clear playlist/library/index/repeat/shuffle state."
  (when simple-mpv-audio--timer
    (cancel-timer simple-mpv-audio--timer)
    (setq simple-mpv-audio--timer nil))
  (when (and simple-mpv-audio--connection
             (process-live-p simple-mpv-audio--connection))
    (delete-process simple-mpv-audio--connection))
  (setq simple-mpv-audio--connection nil)
  (when (and simple-mpv-audio--bridge-process
             (process-live-p simple-mpv-audio--bridge-process))
    (kill-process simple-mpv-audio--bridge-process))
  (setq simple-mpv-audio--bridge-process nil)
  (when (and simple-mpv-audio--process
             (process-live-p simple-mpv-audio--process))
    (kill-process simple-mpv-audio--process))
  (setq simple-mpv-audio--process nil)
  (setq simple-mpv-audio--line-buf ""
        simple-mpv-audio--request-id 0
        simple-mpv-audio--loading nil
        simple-mpv-audio--paused nil
        simple-mpv-audio--duration 0.0
        simple-mpv-audio--position 0.0
        simple-mpv-audio--title ""
        simple-mpv-audio--artist "")
  (clrhash simple-mpv-audio--callbacks))

(defun simple-mpv-audio--start ()
  "Launch the mpv audio process and connect to its IPC."
  (simple-mpv-audio--kill-process)
  (when (eq system-type 'windows-nt)
    ;; Fail loudly before spawning mpv if the bridge cannot run.
    (simple-mpv-audio--bridge-validate))
  (let ((exe (simple-mpv--ensure-executable))
        (ipc-arg (simple-mpv-audio--mpv-ipc-arg)))
    (setq simple-mpv-audio--process
          (make-process
           :name "simple-mpv-audio"
           :command (list exe "--really-quiet" "--no-video" "--idle=yes" ipc-arg)
           :filter #'simple-mpv-audio--proc-filter
           :sentinel #'simple-mpv-audio--proc-sentinel
           :noquery t))
    ;; On Windows, start the Python bridge (named pipe -> TCP)
    (when (eq system-type 'windows-nt)
      (setq simple-mpv-audio--bridge-process
            (simple-mpv-audio--bridge-start)))
    (let ((conn (simple-mpv-audio--ipc-connect-with-retry)))
      (unless conn
        (simple-mpv-audio--kill-process)
        (user-error "simple-mpv-audio: failed to connect to mpv IPC"))
      (setq simple-mpv-audio--connection conn))
    (simple-mpv-audio--observe-properties)))

(defun simple-mpv-audio--reconnect ()
  "Re-establish the IPC connection to a live mpv process.
Restarts the Windows bridge if it died.  Never touches the mpv
process, so the current track keeps playing."
  (when (eq system-type 'windows-nt)
    (when (or (not simple-mpv-audio--bridge-process)
              (not (process-live-p simple-mpv-audio--bridge-process)))
      (simple-mpv-audio--bridge-validate)
      (setq simple-mpv-audio--bridge-process
            (simple-mpv-audio--bridge-start))))
  (let ((conn (simple-mpv-audio--ipc-connect-with-retry)))
    (unless conn
      (user-error "simple-mpv-audio: failed to reconnect to mpv IPC"))
    (setq simple-mpv-audio--connection conn
          simple-mpv-audio--line-buf "")
    (clrhash simple-mpv-audio--callbacks)
    (simple-mpv-audio--observe-properties)))

(defun simple-mpv-audio--ensure-process ()
  "Make sure mpv + IPC are alive; restart if necessary.
A dropped IPC connection with a live mpv process is repaired by
reconnecting only — the mpv process (and the current track) is left
untouched.  Only a dead mpv process triggers a full restart."
  (cond
   ((and simple-mpv-audio--process
         (process-live-p simple-mpv-audio--process))
    (unless (and simple-mpv-audio--connection
                 (process-live-p simple-mpv-audio--connection))
      (condition-case err
          (simple-mpv-audio--reconnect)
        (error
         (message "simple-mpv-audio: IPC reconnect failed (%s), restarting mpv"
                  (error-message-string err))
         (simple-mpv-audio--start)))))
   (t
    (simple-mpv-audio--start))))

(defun simple-mpv-audio--proc-filter (_proc string)
  "Log mpv stdout/stderr output to *Messages*."
  (when (and string (not (string-empty-p string)))
    (message "mpv: %s" (string-trim string))))

(defun simple-mpv-audio--proc-sentinel (proc event)
  "Sentinel for the mpv process.  Clean up on unexpected exit.
Ignores sentinel calls for replaced process objects, so a stale
sentinel cannot kill a freshly restarted mpv."
  (when (memq (process-status proc) '(exit signal))
    (message "simple-mpv-audio: mpv process exited (%s)" (string-trim event))
    (when (eq proc simple-mpv-audio--process)
      (simple-mpv-audio--kill-process))))

(defun simple-mpv-audio--stop ()
  "Kill process + connection, reset ALL state including playlist."
  (simple-mpv-audio--kill-process)
  (setq simple-mpv-audio--playlist nil
        simple-mpv-audio--library  nil
        simple-mpv-audio--index    0
        simple-mpv-audio--repeat   nil
        simple-mpv-audio--shuffle  nil
        simple-mpv-audio--shuffled nil))

;;; Library (scanning / playlist / shuffle)

(defun simple-mpv-audio--scan ()
  "Scan `simple-mpv-audio-directory' one level deep.
Returns (ROOT-FILES . GROUPS): ROOT-FILES are the music files directly
in the directory; GROUPS is a list of ((dir . NAME) (tracks FILE...))
entries for the non-empty subdirectories, name-sorted.  All file lists
are sorted.  Missing or unreadable directories yield an empty result."
  (let* ((root simple-mpv-audio-directory)
         (entries (ignore-errors (directory-files root t)))
         (subdirs (cl-loop for e in entries
                           when (and (file-directory-p e)
                                     (not (string-prefix-p "."
                                                            (file-name-nondirectory e))))
                           collect e))
         (root-files (sort (simple-mpv-audio--scan-files entries)
                           #'string-lessp))
         (groups (cl-loop for d in (sort subdirs #'string-lessp)
                          for files = (sort (simple-mpv-audio--scan-files
                                             (ignore-errors
                                               (directory-files d t)))
                                            #'string-lessp)
                          when files
                          collect (list (cons 'dir (file-name-nondirectory d))
                                        (cons 'tracks files)))))
    (cons root-files groups)))

(defun simple-mpv-audio--scan-files (entries)
  "Return the music files among ENTRIES (absolute directory listing)."
  (cl-loop for e in entries
           for ext = (file-name-extension e)
           when (and (not (file-directory-p e))
                     ext
                     (member (downcase ext) simple-mpv-audio-extensions))
           collect e))

(defun simple-mpv-audio--rebuild ()
  "Rebuild the playlist and browse library by scanning the music directory."
  (let* ((scanned (simple-mpv-audio--scan))
         (root-files (car scanned))
         (groups (cdr scanned)))
    (setq simple-mpv-audio--library
          (append (when root-files (list (cons 'tracks root-files)))
                  groups)
          simple-mpv-audio--playlist
          (cl-loop for node in simple-mpv-audio--library
                   append (cdr (assq 'tracks node)))
          simple-mpv-audio--index 0
          simple-mpv-audio--shuffled nil))
  (length simple-mpv-audio--playlist))

(defun simple-mpv-audio--current-playlist-index ()
  "Playlist index of the current track.
Maps `simple-mpv-audio--index' through the shuffle permutation when
shuffle is active; identical to it otherwise."
  (if (and simple-mpv-audio--shuffle simple-mpv-audio--shuffled)
      (nth simple-mpv-audio--index simple-mpv-audio--shuffled)
    simple-mpv-audio--index))

(defun simple-mpv-audio--reshuffle (&optional keep)
  "Shuffle the playlist order into `simple-mpv-audio--shuffled'.
The track at playlist index KEEP (default: the current track) stays
current; `simple-mpv-audio--index' is set to its position in the new
shuffled sequence."
  (let* ((n (length simple-mpv-audio--playlist))
         (keep (or keep (simple-mpv-audio--current-playlist-index))))
    (setq simple-mpv-audio--shuffled (cl-loop for i below n collect i))
    (cl-loop for i from (1- n) downto 1
             for j = (random (1+ i))
             do (cl-rotatef (nth i simple-mpv-audio--shuffled)
                            (nth j simple-mpv-audio--shuffled)))
    (setq simple-mpv-audio--index
          (or (cl-position keep simple-mpv-audio--shuffled) 0))))

(defun simple-mpv-audio--current-file ()
  "Absolute path of the current playlist entry."
  (when simple-mpv-audio--playlist
    (nth (simple-mpv-audio--current-playlist-index)
         simple-mpv-audio--playlist)))

(defun simple-mpv-audio--current-dir ()
  "Return the name of the current track's subdirectory, or nil if the
current track sits directly in `simple-mpv-audio-directory'."
  (when-let ((file (simple-mpv-audio--current-file))
             (dir (file-name-directory file)))
    (let ((root (directory-file-name
                 (expand-file-name simple-mpv-audio-directory))))
      (unless (string-equal (directory-file-name dir) root)
        (file-name-nondirectory (directory-file-name dir))))))

;;; Track loading / metadata

(defun simple-mpv-audio--parse-pairs (data)
  "Convert mpv key-value DATA into an alist of strings.
Handles [[k v] ...] (list pairs), (k v k v ...) flat, and
((k . v) ...) dotted alist forms."
  (cond ((null data) nil)
        ((consp (car data))
         (mapcar (lambda (p)
                   (cons (format "%s" (car p))
                         (format "%s" (if (consp (cdr p)) (cadr p) (cdr p)))))
                 data))
        (t (cl-loop for (k v) on data by #'cddr
                    collect (cons (format "%s" k) (format "%s" v))))))

(defun simple-mpv-audio--set-metadata (data)
  "Extract artist and title from mpv metadata DATA."
  (let ((props (simple-mpv-audio--parse-pairs data)))
    (setq simple-mpv-audio--artist
          (or (cdr (assoc "artist" props))
              (cdr (assoc "ARTIST" props)) ""))
    (setq simple-mpv-audio--title
          (or (cdr (assoc "title" props))
              (cdr (assoc "TITLE" props))
              simple-mpv-audio--title))))

(defun simple-mpv-audio--load (&optional index)
  "Load track at INDEX and start playing."
  (let ((i (or index simple-mpv-audio--index)))
    (unless (and simple-mpv-audio--playlist
                 (>= i 0) (< i (length simple-mpv-audio--playlist)))
      (error "simple-mpv-audio: invalid playlist index %d" i))
    (setq simple-mpv-audio--index i
          simple-mpv-audio--loading t
          simple-mpv-audio--artist ""
          simple-mpv-audio--duration 0.0
          simple-mpv-audio--position 0.0)
    (let ((file (simple-mpv-audio--current-file)))
      (setq simple-mpv-audio--title
            (file-name-sans-extension (file-name-nondirectory file)))
      (simple-mpv-audio--send
       `("loadfile" ,file "replace")
       ;; Metadata is fetched on the file-loaded property event, not
       ;; after a fixed delay.
       (lambda (_) (setq simple-mpv-audio--loading nil)))
      (simple-mpv-audio--refresh-ui))))

(defun simple-mpv-audio--on-end-file (reason)
  "Handle the end of a file.  REASON is \\='eof' or a string."
  (when (and (not simple-mpv-audio--loading) (equal reason "eof"))
    (cond ((eq simple-mpv-audio--repeat 'one)
           (simple-mpv-audio--load simple-mpv-audio--index))
          ((or (eq simple-mpv-audio--repeat 'all)
               (< (1+ simple-mpv-audio--index)
                  (length simple-mpv-audio--playlist)))
           (simple-mpv-audio-next))
          (t
           (setq simple-mpv-audio--paused t)
           (simple-mpv-audio--refresh-ui)
           (message "simple-mpv-audio: end of playlist")))))

(defun simple-mpv-audio--poll-position ()
  "Refresh `simple-mpv-audio--position' from mpv (for the UI timer)."
  (when (and simple-mpv-audio--connection
             (process-live-p simple-mpv-audio--connection))
    (simple-mpv-audio--send
     '("get_property" "time-pos")
     (lambda (data) (when data (setq simple-mpv-audio--position data))))))

;;; Cleanup on Emacs exit

(defun simple-mpv-audio--kill-emacs-hook ()
  "Kill the mpv process when Emacs exits."
  (when (and simple-mpv-audio--process
             (process-live-p simple-mpv-audio--process))
    (kill-process simple-mpv-audio--process)))

(add-hook 'kill-emacs-hook #'simple-mpv-audio--kill-emacs-hook)

(provide 'simple-mpv-audio-bridge)
;;; simple-mpv-audio-bridge.el ends here
