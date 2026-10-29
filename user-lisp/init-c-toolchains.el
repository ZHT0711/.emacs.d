;;; init-c-toolchains.el --- Coexisting GCC/Clang single-file tools -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'project)
(require 'subr-x)

(defcustom my-c-toolchain 'gcc
  "Compiler family for standalone C/C++ files.  Each buffer may select its own."
  :type '(choice (const gcc) (const clang))
  :group 'tools)
(make-variable-buffer-local 'my-c-toolchain)

(defun my-c-toolchain-cxx-p ()
  "Whether the current source buffer is C++."
  (if (fboundp 'my-compile-cxx-p)
      (my-compile-cxx-p)
    (member (file-name-extension (or buffer-file-name ""))
            '("cpp" "cc" "cp" "cxx" "c++" "C" "cppm" "ixx"))))

(defun my-c-toolchain-compiler (cxx)
  "Return the selected compiler name, with CXX choosing the C++ driver."
  (if (eq my-c-toolchain 'clang)
      (if cxx "clang++" "clang")
    (if cxx "g++" "gcc")))

(defun my-c-toolchain--external-config-p ()
  "Whether this source already has project-level clangd/build configuration."
  (when buffer-file-name
    (or (locate-dominating-file buffer-file-name "compile_commands.json")
        (locate-dominating-file buffer-file-name "compile_flags.txt")
        (locate-dominating-file buffer-file-name ".clangd")
        (let ((root (or (when-let* ((project (project-current nil)))
                          (project-root project))
                        default-directory)))
          (cl-some (lambda (dir)
                     (file-exists-p (expand-file-name
                                    (concat dir "/compile_commands.json") root)))
                   '("build" "cmake-build-debug" "cmake-build-release" "out/build"))))))

(defun my-c-toolchain-update-clangd-db ()
  "Maintain an Emacs-only fallback database, without writing to source projects.
Explicit project compilation databases/configuration always take precedence."
  (when (and buffer-file-name
             (not (file-remote-p buffer-file-name))
             (member (file-name-extension buffer-file-name)
                     '("c" "C" "cc" "cp" "cpp" "cxx" "c++" "cppm" "ixx"))
             (not (my-c-toolchain--external-config-p)))
    (let* ((root (or (when-let* ((project (project-current nil)))
                       (project-root project))
                     (file-name-directory buffer-file-name)))
           (cache-root (expand-file-name "clangd/compdb/"
                                         (if (boundp 'nn-directory) nn-directory
                                           (locate-user-emacs-file ".nn/"))))
           (dir (expand-file-name (secure-hash 'sha1 (expand-file-name root)) cache-root))
           (database (expand-file-name "compile_commands.json" dir))
           (cxx (my-c-toolchain-cxx-p))
           (compiler (executable-find (my-c-toolchain-compiler cxx)))
           (source (expand-file-name buffer-file-name)))
      (when compiler
        (let* ((old (when (file-readable-p database)
                      (ignore-errors
                        (with-temp-buffer
                          (insert-file-contents database)
                          (append (json-parse-buffer :object-type 'plist :array-type 'array)
                                  nil)))))
               (entries (cl-remove-if
                         (lambda (entry)
                           (equal (downcase (or (plist-get entry :file) ""))
                                  (downcase source))) old))
               (entry (list :directory (file-name-directory source)
                            :file source
                            :arguments (vector compiler
                                               (if cxx "-std=c++20" "-std=c17")
                                               "-Wall" "-Wextra" "-c" source))))
          (make-directory dir t)
          (let ((coding-system-for-write 'utf-8-unix))
            (with-temp-file database
              (insert (json-serialize (vconcat (cons entry entries))))))
          dir)))))

(defun my-c-select-toolchain (toolchain)
  "Select GCC or Clang for this standalone source buffer, including Quickrun."
  (interactive
   (list (intern (completing-read "C/C++ compiler: " '("gcc" "clang") nil t))))
  (unless (and buffer-file-name
               (fboundp 'my-compile-lang)
               (memq (my-compile-lang) '(c cxx)))
    (user-error "Save this buffer as a .c or .cpp file first"))
  (when (or (my-compile-c-cmake-root) (my-compile-c-make-root))
    (user-error "This project uses CMake/Make; choose its compiler in the build configuration"))
  (unless (memq toolchain '(gcc clang)) (user-error "Choose gcc or clang"))
  (let ((compiler (if (eq toolchain 'clang)
                      (if (my-c-toolchain-cxx-p) "clang++" "clang")
                    (if (my-c-toolchain-cxx-p) "g++" "gcc"))))
    (unless (executable-find compiler) (user-error "Compiler not found: %s" compiler))
    (setq-local my-c-toolchain toolchain)
    (setq-local quickrun-option-cmdkey
                (if (my-c-toolchain-cxx-p)
                    (if (eq toolchain 'clang) "c++/clang++-c++20" "c++/g++-c++20")
                  (if (eq toolchain 'clang) "c/clang-c17" "c/gcc-c17")))
    (setq-local compile-command (my-compile-command))
    (my-c-toolchain-update-clangd-db)
    (message "This file: %s; C-c b b compile, C-c b r run, C-c b i interactive" compiler)))

(dolist (hook '(c-mode-hook c-ts-mode-hook c++-mode-hook c++-ts-mode-hook simpc-mode-hook))
  (add-hook hook #'my-c-toolchain-update-clangd-db))

(provide 'init-c-toolchains)
;;; init-c-toolchains.el ends here
