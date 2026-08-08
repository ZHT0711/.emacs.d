;;; simple-mpv-audio-ui.el --- Audio player UI (display)  -*- lexical-binding: t; -*-

;;; Commentary:

;; Display layer for the mpv audio player: the music browser
;; (*simple-mpv-browse*) and the player panel (*simple-mpv-audio*).
;;
;; It renders playback state and calls the control API from
;; simple-mpv-audio-bridge.el; it never mutates playback state itself.
;; Playback signals changes through `simple-mpv-audio--refresh-hook',
;; which this file subscribes to.
;;
;; The library is scanned one level deep by the bridge layer: files
;; directly in `simple-mpv-audio-directory' are listed without a
;; header, and each non-empty immediate subdirectory becomes a headed
;; group.  The browse buffer is rendered recursively from
;; `simple-mpv-audio--library' (depth 1), with each line built from a
;; mode-line-style format list.

;;; Code:

(require 'simple-mpv-audio-bridge)
(require 'cl-lib)

;;; Customization

(defcustom simple-mpv-audio-progress-width 30
  "Width in characters of the thin progress bar."
  :type 'integer
  :group 'simple-mpv-audio)

;;; Faces

(defface simple-mpv-audio-current-track
  '((((class color) (min-colors 88))
     :weight bold :underline t :background "#4b4b7a")
    (t :weight bold :underline t :inherit highlight))
  "Face for the currently playing track in the browse list."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-dir
  '((((class color) (min-colors 88))
     :weight bold :foreground "#9a9ab0")
    (t :weight bold :inherit default))
  "Face for directory header lines in the browse list."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-current-dir
  '((((class color) (min-colors 88))
     :weight bold :foreground "#ffd866")
    (t :weight bold :inverse-video t))
  "Face for the directory header containing the current track."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-title
  '((t :weight bold :height 1.3))
  "Face for the track title in the player panel."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-artist
  '((t :foreground "dim gray" :slant italic))
  "Face for the artist name in the player panel."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-button
  '((t :weight bold))
  "Face for player control buttons."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-button-active
  '((((class color) (min-colors 88))
     :weight bold :foreground "#ffd866" :background "#4b4b7a")
    (t :weight bold :inverse-video t))
  "Face for active (enabled) player control buttons."
  :group 'simple-mpv-audio)

(defface simple-mpv-audio-time
  '((t :foreground "dim gray"))
  "Face for the playback time text."
  :group 'simple-mpv-audio)

;;; Keymaps

(defvar simple-mpv-audio-mode-map
  (let ((map (make-sparse-keymap)))
    (suppress-keymap map)
    (keymap-set map "SPC" #'simple-mpv-audio-toggle-pause)
    (keymap-set map "n"   #'simple-mpv-audio-next)
    (keymap-set map "p"   #'simple-mpv-audio-prev)
    (keymap-set map "s"   #'simple-mpv-audio-toggle-shuffle)
    (keymap-set map "r"   #'simple-mpv-audio-toggle-repeat)
    (keymap-set map "<right>" #'simple-mpv-audio-seek-forward)
    (keymap-set map "<left>"  #'simple-mpv-audio-seek-backward)
    (keymap-set map "m"   #'simple-mpv-audio-menu)
    (keymap-set map "q"   #'simple-mpv-audio-quit)
    (keymap-set map "g"   #'simple-mpv-audio-rescan)
    (keymap-set map "b"   #'simple-mpv-audio-browse)
    (keymap-set map "?"   #'describe-mode)
    map))

(defvar simple-mpv-audio-browse-mode-map
  (let ((map (make-sparse-keymap)))
    (suppress-keymap map)
    (keymap-set map "n"   #'next-line)
    (keymap-set map "p"   #'previous-line)
    (keymap-set map "RET" #'simple-mpv-audio-browse-play)
    (keymap-set map "SPC" #'simple-mpv-audio-toggle-pause)
    (keymap-set map "g"   #'simple-mpv-audio-rescan)
    (keymap-set map "q"   #'quit-window)
    map))

;;; Buttons (no button.el dependency)

(defvar simple-mpv-audio-button-map
  (let ((map (make-sparse-keymap)))
    (define-key map [mouse-1] #'simple-mpv-audio--button-click)
    (define-key map [mouse-2] #'simple-mpv-audio--button-click)
    (define-key map [return]  #'simple-mpv-audio--button-activate)
    map)
  "Keymap for the clickable buttons in the player panel.")

(defun simple-mpv-audio--button-click (event)
  "Invoke the button action at the mouse EVENT position."
  (interactive "e")
  (let* ((pos (posn-point (event-start event)))
         (action (and pos (get-text-property pos 'action))))
    (when (functionp action)
      (funcall action nil))))

(defun simple-mpv-audio--button-activate ()
  "Invoke the button action at point (RET)."
  (interactive)
  (let ((action (get-text-property (point) 'action)))
    (when (functionp action)
      (funcall action nil))))

(defun simple-mpv-audio--button (label action &optional active)
  "Return LABEL as a clickable button invoking ACTION.
The whole LABEL (including surrounding spaces) is clickable with
mouse-1/mouse-2 or RET.  When ACTIVE is non-nil, style it as enabled."
  (propertize (concat " " label " ")
              'face (if active
                        'simple-mpv-audio-button-active
                      'simple-mpv-audio-button)
              'keymap simple-mpv-audio-button-map
              'action (lambda (_b) (funcall action))
              'mouse-face 'highlight
              'help-echo (format "%s (mouse-1 / RET)" action)))

;;; Format lists (mode-line style)
;; Each rendered line is described by a list of items, like
;; `mode-line-format': literal strings, (:eval FORM), (:propertize ITEM
;; &rest PROPS) and nested lists.  (:eval ...) forms run under `eval'
;; with lexical-binding, so they can only reference global state — which
;; is all these renderers need.

(defun simple-mpv-audio--format-item (item)
  "Render one format-list ITEM for `simple-mpv-audio--format'."
  (pcase item
    ((pred null) "")
    ((pred stringp) item)
    (`(:eval ,form) (format "%s" (eval form t)))
    (`(:propertize ,item . ,props)
     (apply #'propertize
            (simple-mpv-audio--format-item item)
            (cl-loop for (k v) on props by #'cddr
                     append (list k (simple-mpv-audio--format-prop v)))))
    ((pred consp) (simple-mpv-audio--format item))
    (_ "")))

(defun simple-mpv-audio--format (fmt)
  "Render FMT, a mode-line-style format list, to a string.
FMT is a list of items; a bare (:eval ...) or (:propertize ...) form
is also accepted.  Items may be literal strings, nested lists, nil
(skipped), (:eval FORM), or (:propertize ITEM &rest PROPS) which
propertizes the rendered ITEM.  PROPS values may be (:eval FORM) or
(quote SYM) forms."
  (if (and (consp fmt) (memq (car fmt) '(:eval :propertize)))
      (simple-mpv-audio--format-item fmt)
    (mapconcat #'simple-mpv-audio--format-item fmt "")))

(defun simple-mpv-audio--format-prop (value)
  "Resolve a property VALUE for `simple-mpv-audio--format'."
  (pcase value
    (`(:eval ,form) (eval form t))
    (`(quote ,x) x)
    (_ value)))

;;; Player panel

(defun simple-mpv-audio--panel-title ()
  "Title text for the player panel."
  (or simple-mpv-audio--title "No track"))

(defun simple-mpv-audio--panel-artist ()
  "Artist text for the player panel."
  (if (string-empty-p simple-mpv-audio--artist)
      "none" simple-mpv-audio--artist))

(defun simple-mpv-audio--lcr (left mid right)
  "Return a line with LEFT at the left edge and RIGHT at the right edge,
with MID centered between them."
  (let* ((win (get-buffer-window (current-buffer) t))
         (w   (if win (window-width win) 80))
         (l (length left)) (m (length mid)) (r (length right)))
    (if (>= (+ l m r) w)
        (format "%s%s%s" left mid right)
      (let ((gap (- w (+ l m r))))
        (format "%s%s%s%s%s" left
                (make-string (/ gap 2) ?\s) mid
                (make-string (- gap (/ gap 2)) ?\s) right)))))

(defun simple-mpv-audio--fmt-time (secs)
  "Format SECS as MM:SS, clamped to non-negative values."
  (let* ((s (max 0 (round (or secs 0))))
         (m (/ s 60)))
    (format "%02d:%02d" m (% s 60))))

(defun simple-mpv-audio--thin-bar (&optional width)
  "Return a thin progress bar of WIDTH characters.
Played portion uses a heavy dash and a bright face, the remaining
portion a light dash and a dim face, so the split stays visible even
where the two faces render alike."
  (let* ((pos   simple-mpv-audio--position)
         (dur   (max simple-mpv-audio--duration 0.01))
         (ratio (/ pos dur))
         (w     (or width simple-mpv-audio-progress-width))
         (done  (max 0 (min w (round (* ratio w)))))
         (left  (- w done)))
    (concat (propertize (make-string done ?━)
                        'face 'simple-mpv-audio-title)
            (propertize (make-string left ?─)
                        'face 'simple-mpv-audio-artist))))

(defun simple-mpv-audio--render ()
  "Redraw the player panel — one line:
TITLE - ARTIST on the left, controls centered,
thin progress bar with time on the right."
  (when-let ((buf (get-buffer "*simple-mpv-audio*")))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert
           (simple-mpv-audio--lcr
            (simple-mpv-audio--format
             `((:propertize (:eval (simple-mpv-audio--panel-title))
                            face simple-mpv-audio-title)
               " - "
               (:propertize (:eval (simple-mpv-audio--panel-artist))
                            face simple-mpv-audio-artist)))
            (mapconcat #'identity
                       (list (simple-mpv-audio--button
                              "🙏" #'simple-mpv-audio-toggle-shuffle
                              simple-mpv-audio--shuffle)
                             (simple-mpv-audio--button
                              "👈" #'simple-mpv-audio-prev)
                             ;; Fixed label: toggling does not depend on
                             ;; pause state.
                             (simple-mpv-audio--button
                              "⏯" #'simple-mpv-audio-toggle-pause)
                             (simple-mpv-audio--button
                              "👉" #'simple-mpv-audio-next)
                             (simple-mpv-audio--button
                              "🤏" #'simple-mpv-audio-toggle-repeat
                              simple-mpv-audio--repeat))
                       "  ")
            (concat (simple-mpv-audio--thin-bar)
                    "  "
                    (simple-mpv-audio--format
                     `(:propertize
                       ,(format "%s / %s"
                                (simple-mpv-audio--fmt-time
                                 simple-mpv-audio--position)
                                (simple-mpv-audio--fmt-time
                                 simple-mpv-audio--duration))
                       face simple-mpv-audio-time))))
          (goto-char (point-min))))))))

(defun simple-mpv-audio--open-player ()
  "Show the player panel, splitting the window above the current one."
  (let ((buf (get-buffer-create "*simple-mpv-audio*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'simple-mpv-audio-mode)
        (simple-mpv-audio-mode)))
    (simple-mpv-audio--render)
    (let ((win (get-buffer-window buf t)))
      (if win
          (select-window win)
        (let ((selected (selected-window)))
          (setq win (split-window selected nil 'above))
          (set-window-buffer win buf)
          (select-window win)))
      (ignore-errors (fit-window-to-buffer win 3 2))
      buf)))

;;; Browse list
;; Rendered recursively from `simple-mpv-audio--library' (depth 1):
;; root-level files carry no header, each subdirectory group gets a
;; header line.  Each line is built from a mode-line-style format list.

(defvar simple-mpv-audio--browse-dir-name nil
  "Name of the directory group currently being rendered (dynamic).")

(defun simple-mpv-audio--browse-dir-face ()
  "Face for the directory header currently being rendered."
  (if (equal simple-mpv-audio--browse-dir-name
             (simple-mpv-audio--current-dir))
      'simple-mpv-audio-current-dir
    'simple-mpv-audio-dir))

(defun simple-mpv-audio--browse-dir-line (name)
  "Return the header line for subdirectory NAME.
Highlighted when the current track lives in that directory."
  (let ((simple-mpv-audio--browse-dir-name name))
    (simple-mpv-audio--format
     `(:propertize ,(format "── %s\n" name)
                   face (:eval (simple-mpv-audio--browse-dir-face))))))

(defun simple-mpv-audio--browse-track-line (file idx-map)
  "Render the browse line for FILE via a format list.
IDX-MAP maps file paths to their flat playlist index.  The flat index
is stored as a text property so RET can find the track even with
directory header lines in between."
  (let* ((i (gethash file idx-map))
         (current (= i (simple-mpv-audio--current-playlist-index)))
         (text (format "%s%3d. %s\n"
                       (if current "> " "  ")
                       (1+ i)
                       (file-name-sans-extension
                        (file-name-nondirectory file)))))
    (simple-mpv-audio--format
     `(:propertize ,text
                   face ,(when current 'simple-mpv-audio-current-track)
                   simple-mpv-audio-track-idx ,i))))

(defun simple-mpv-audio--browse-render-node (node idx-map)
  "Render a library NODE to a string, recursing one level.
NODE is either (tracks FILE...) for root-level files (no header) or
((dir . NAME) (tracks FILE...)) for a subdirectory group; recursion
depth is bounded by the structure itself."
  (pcase node
    (`(tracks . ,tracks)
     (mapconcat (lambda (f)
                  (simple-mpv-audio--browse-track-line f idx-map))
                tracks ""))
    (`((dir . ,name) (tracks . ,tracks))
     (concat (simple-mpv-audio--browse-dir-line name)
             (mapconcat (lambda (f)
                          (simple-mpv-audio--browse-track-line f idx-map))
                        tracks "")))
    (_ "")))

(defun simple-mpv-audio--browse-render ()
  "Return the full browse buffer text.
Root-level files are listed without a header; each non-empty
subdirectory gets a header line above its tracks."
  (if (null simple-mpv-audio--playlist)
      "No music files.  Press g to rescan.\n"
    (let ((idx-map (make-hash-table :test 'equal
                                    :size (length simple-mpv-audio--playlist))))
      (cl-loop for f in simple-mpv-audio--playlist
               for i from 0
               do (puthash f i idx-map))
      (mapconcat (lambda (node)
                   (simple-mpv-audio--browse-render-node node idx-map))
                 simple-mpv-audio--library ""))))

(defun simple-mpv-audio--render-browse ()
  "Redraw the browse buffer from `simple-mpv-audio--library'."
  (when-let ((buf (get-buffer "*simple-mpv-browse*")))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let ((inhibit-read-only t)
              (pos (point)))
          (erase-buffer)
          (insert (simple-mpv-audio--browse-render))
          (goto-char (min pos (point-max))))))))

;; Wire the UI into the playback layer: playback runs this hook after
;; every state change, so the UI stays fresh without playback code ever
;; calling UI functions directly.

(add-hook 'simple-mpv-audio--refresh-hook
          (lambda ()
            (simple-mpv-audio--render)
            (simple-mpv-audio--render-browse)))

;;; Modes

(define-derived-mode simple-mpv-audio-mode special-mode "♫ mpv"
  "Major mode for the simple-mpv audio player panel.
\\{simple-mpv-audio-mode-map}"
  (setq buffer-read-only t)
  (setq-local cursor-type nil)
  (setq-local mode-line-format nil)
  (setq-local truncate-lines t))

(define-derived-mode simple-mpv-audio-browse-mode special-mode "♫ Browse"
  "Major mode for browsing the music library.
\\{simple-mpv-audio-browse-mode-map}"
  (setq buffer-read-only t)
  (setq-local truncate-lines t))

;;; Menu (internal)

(defun simple-mpv-audio-menu ()
  "Show the command menu."
  (interactive)
  (let ((choice (completing-read
                 "mpv Audio: "
                 '("Play / Pause" "Next track" "Previous track"
                   "Seek forward" "Seek backward"
                   "Toggle shuffle" "Toggle repeat" "Browse library"
                   "Rescan directory" "Quit")
                 nil t)))
    (pcase choice
      ("Play / Pause"      (simple-mpv-audio-toggle-pause))
      ("Next track"        (simple-mpv-audio-next))
      ("Previous track"    (simple-mpv-audio-prev))
      ("Seek forward"      (simple-mpv-audio-seek-forward))
      ("Seek backward"     (simple-mpv-audio-seek-backward))
      ("Toggle shuffle"    (simple-mpv-audio-toggle-shuffle))
      ("Toggle repeat"     (simple-mpv-audio-toggle-repeat))
      ("Browse library"    (simple-mpv-audio-browse))
      ("Rescan directory"  (simple-mpv-audio-rescan))
      ("Quit"              (simple-mpv-audio-quit)))))

;;; Timer

(defun simple-mpv-audio--start-timer ()
  "Start the progress update timer (every 0.5s)."
  (unless simple-mpv-audio--timer
    (setq simple-mpv-audio--timer
          (run-at-time t 0.5 #'simple-mpv-audio--tick))))

(defun simple-mpv-audio--tick ()
  "Refresh position from mpv and re-render the player panel.
Pause state is not polled here: the observed \"pause\" property
events already keep `simple-mpv-audio--paused' fresh."
  (simple-mpv-audio--poll-position)
  (simple-mpv-audio--render))

;;; Browse play (internal, bound in browse keymap)

(defun simple-mpv-audio-browse-play ()
  "Play the track on the current line in the browse buffer."
  (interactive)
  (unless (derived-mode-p 'simple-mpv-audio-browse-mode)
    (user-error "Not in a simple-mpv-audio browse buffer"))
  (let* ((idx (get-text-property (line-beginning-position)
                                 'simple-mpv-audio-track-idx)))
    (unless idx
      (user-error "No track on this line"))
    ;; `simple-mpv-audio--load' takes a position in the playback
    ;; sequence; convert the clicked playlist row through the
    ;; shuffle permutation when shuffle is active.
    (let ((seq-idx (if (and simple-mpv-audio--shuffle
                            simple-mpv-audio--shuffled)
                       (or (cl-position idx simple-mpv-audio--shuffled) idx)
                     idx)))
      (simple-mpv-audio--ensure-process)
      (simple-mpv-audio--start-timer)
      (simple-mpv-audio--load seq-idx)
      (simple-mpv-audio--open-player)
      (message "Playing: %s" simple-mpv-audio--title))))

;;; Public commands

;;;###autoload
(defun simple-mpv-audio ()
  "Start the simple-mpv audio player.
Scans `simple-mpv-audio-directory' and displays the player panel.
Use `simple-mpv-audio-browse' (or press `b') to browse the library.

Player keys (*simple-mpv-audio*):
  SPC       play / pause        n / p   next / previous track
  <right>   seek +5s            <left>  seek -5s
  s         toggle shuffle      r       toggle repeat
  b         browse library      m       command menu
  g         rescan directory    q       quit"
  (interactive)
  (unless simple-mpv-audio--playlist
    (let ((n (simple-mpv-audio--rebuild)))
      (if (= n 0)
          (message "simple-mpv-audio: no music files in %s"
                   (abbreviate-file-name simple-mpv-audio-directory))
        (message "simple-mpv-audio: found %d file(s)" n))))
  (unless simple-mpv-audio--playlist
    (user-error "No music files — check `simple-mpv-audio-directory'"))
  (simple-mpv-audio--ensure-process)
  (simple-mpv-audio--start-timer)
  (let ((buf (get-buffer-create "*simple-mpv-audio*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'simple-mpv-audio-mode)
        (simple-mpv-audio-mode)))
    (display-buffer buf '(display-buffer-at-bottom (window-height . 3))))
  (simple-mpv-audio--render)
  (simple-mpv-audio--send '("get_property" "filename")
                          (lambda (filename)
                            ;; mpv can report "" while idle, which is
                            ;; truthy in Emacs Lisp — check explicitly.
                            (unless (and filename (not (string-empty-p filename)))
                              (simple-mpv-audio--load simple-mpv-audio--index)))))

;;;###autoload
(defun simple-mpv-audio-browse ()
  "Open the music library browser.
Lists music files grouped by folder (one level deep).
Press RET to play, q to close."
  (interactive)
  (unless simple-mpv-audio--playlist
    (let ((n (simple-mpv-audio--rebuild)))
      (if (= n 0)
          (message "simple-mpv-audio: no music files in %s"
                   (abbreviate-file-name simple-mpv-audio-directory))
        (message "simple-mpv-audio: found %d file(s)" n))))
  (let ((buf (get-buffer-create "*simple-mpv-browse*")))
    (with-current-buffer buf
      (simple-mpv-audio-browse-mode))
    (simple-mpv-audio--render-browse)
    (pop-to-buffer buf)))

;;;###autoload
(defun simple-mpv-audio-rescan ()
  "Rescan the music directory and refresh the browse list."
  (interactive)
  (let ((n (simple-mpv-audio--rebuild)))
    (message "simple-mpv-audio: found %d file(s)" n)
    (simple-mpv-audio--render-browse)))

;;;###autoload
(defun simple-mpv-audio-quit ()
  "Stop playback, kill mpv, and close all simple-mpv-audio buffers."
  (interactive)
  (simple-mpv-audio--stop)
  (ignore-errors (kill-buffer "*simple-mpv-audio*"))
  (ignore-errors (kill-buffer "*simple-mpv-browse*")))

(provide 'simple-mpv-audio-ui)
;;; simple-mpv-audio-ui.el ends here
