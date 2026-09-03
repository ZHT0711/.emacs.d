;;; init-rime.el --- RIME Chinese input (GNU/Linux incl. WSL & Windows) -*- lexical-binding: t; -*-

;; RIME input method via the `rime' package (rime-emacs, needs librime).
;;
;; - GNU/Linux (incl. WSL): system librime from apt (librime-dev librime1t64),
;;   share data at /usr/share/rime-data, user data at ~/.emacs.d/rime.
;;
;; - Windows (native Emacs): reuses the user's existing Weasel/Rime setup:
;;     * engine DLL: ~/librime-win/dist/lib/librime.dll  -- self-contained
;;       build; replace that file with a copy of Weasel's rime.dll so the
;;       version matches the user data (see ~/librime-win/README note).
;;     * compiled module: elpa/rime-*/librime-emacs.dll (built with ucrt64 gcc:
;;       gcc lib.c -shared -I<emacs include> -I~/librime-win/dist/include
;;           -L~/librime-win/dist/lib -lrime -o librime-emacs.dll)
;;     * user data: Weasel RimeUserDir (defaults to E:/Rime; tweak below if
;;       your RimeUserDir differs).
;;     * share data: Weasel built-in data dir (adjust on Weasel upgrades).

(defvar nn-rime-dll-dir
  (and (eq system-type 'windows-nt)
       (expand-file-name "librime-win/dist/lib/" "~"))
  "Directory holding librime.dll on Windows (nil elsewhere).")

(defvar nn-rime-user-data-dir
  (cond ((eq system-type 'windows-nt)
         (or (getenv "RIME_USER_DIR") "E:/Rime"))
        (t (expand-file-name "rime" user-emacs-directory)))
  "Rime user data dir (schemas, userdb).")

(defvar nn-rime-share-data-dir
  (cond ((eq system-type 'windows-nt)
         "D:/Program Files/Rime/weasel-0.17.4/data")
        (t "/usr/share/rime-data"))
  "Rime share data dir (built-in schemas, opencc data).")

(defvar nn-rime-available
  (or (and (eq system-type 'gnu/linux)
           (file-exists-p "/usr/include/rime_api.h"))
      (and (eq system-type 'windows-nt)
           nn-rime-dll-dir
           (file-exists-p (expand-file-name "librime.dll" nn-rime-dll-dir))
           (file-exists-p nn-rime-user-data-dir)
           (file-exists-p nn-rime-share-data-dir)))
  "Non-nil when a usable librime is present on this host.")

(when nn-rime-available
  (use-package rime
    :ensure t
    ;; Must load rime.el up front so `register-input-method' actually runs
    ;; (its autoloads reference `rime-title', which is only defined after
    ;; rime.el is loaded); otherwise C-\ fails with
    ;; "Can't activate input method rime".  The librime engine itself stays
    ;; deferred until the input method is activated.
    :demand t
    :custom
    (rime-user-data-dir nn-rime-user-data-dir)
    (rime-share-data-dir nn-rime-share-data-dir)
    ;; Posframe popup on GUI, minibuffer candidates in terminal (-nw).
    (rime-show-candidate (if (display-graphic-p) 'posframe 'minibuffer))
    :init
    (when nn-rime-dll-dir
      ;; Let the module loader resolve librime.dll (DLL search uses PATH).
      (setenv "PATH"
              (concat nn-rime-dll-dir path-separator (getenv "PATH"))))
    (setq default-input-method "rime")))

(provide 'init-rime)
;;; init-rime.el ends here
