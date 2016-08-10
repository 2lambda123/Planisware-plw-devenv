
;; we will generate a command and an entry per version listed here
(defvar *opx2-installations-paths* nil)
;;  '( "600SP0" "/home/troche/opx2/600SP0install/modules/bin/Lx86_64/"
;;     "610SP1" "/home/troche/opx2/install/modules/bin/Lx86_64/"))

(defvar *opx2-installations-paths-conf-file* "planisware-versions.conf")

(defvar *runtime-function-name*
  "runopx2%s")

(defvar *runtime-function-body*
  "(defun %s ()
    (interactive)
    (runopx2runtime \"%s\"))")

(defvar *runtime-exe* (if (on-ms-windows) "intranet.exe" "opx2-intranet.exe"))

(defvar *runtime-dxl* (if (on-ms-windows) "intranet.dxl" "opx2-intranet.dxl"))

(defvar *planisware-menu-name* "Planisware")

(defvar *start-planisware-menu-item* "Start Planisware %s ...")

(defvar *runtime-verbose* nil)

(defvar *display-windows-console* nil)

(defun trim-string (string)
  "Remove white spaces in beginning and ending of STRING.
White space here is any of: space, tab, emacs newline (line feed, ASCII 10)."
  (replace-regexp-in-string "\\`[ \t\n]*" "" (replace-regexp-in-string "[ \t\n]*\\'" "" string))
)

(defun runopx2runtime (rootdir)
  (catch 'exit
    (let* ((intranetini (read-file-name "Please enter the location of your intranet.ini file : " "~" "intranet.ini" t))
	   (satdir      (subseq intranetini 0 (min (1+ (position ?/ intranetini :from-end t))
						   (length intranetini)))))
      (unless (string-match ".*/intranet.ini" intranetini)
	(message "%s is not a valid path to an intranet.ini" intranetini)
	(throw 'exit nil))
      (unless (file-exists-p satdir)
	(message "Directory %s not found ! " satdir)
	(throw 'exit nil))
      (when *runtime-verbose*
	(message "Starting in directory %s" satdir))
      (setq fi::started-via-file nil)
      (unless (on-ms-windows)
	(setenv "OPX2_HOME" (substring rootdir 0 (1- (length rootdir)))))
      (let* ((mt (if (on-ms-windows) "" (format "/%s" (trim-string (shell-command-to-string (format "%sbin/machine" (replace-regexp-in-string "[ ]" "\\ " rootdir nil t)))))))
	     (rootdir (format "%sbin%s" rootdir mt))	     
	     (exe (format "%s/%s" rootdir *runtime-exe*)))
	(unless (file-exists-p exe)
	  (message "Planisware executable %s not found !!" exe)
	  (throw 'exit nil))
	(fi:common-lisp fi:common-lisp-buffer-name
			satdir
			exe
			(append *start-emacs-lisp-interface*
				(when *display-windows-console* (list "+cc" "+p"))
				(list
				 "-H" rootdir
				 "-L" (format "%semacs-runtime.lisp" *opx2-network-folder-work-path*)
				 "-e" "(setq excl::*restart-app-function* nil)"
				 ))
			fi:common-lisp-host
			(format "%s/%s" rootdir *runtime-dxl*))
	(process-send-string fi:common-lisp-buffer-name "(:start-emacs-runtime-mode)\n")
	(switch-to-buffer fi:common-lisp-buffer-name)))))

(defun load-version-configuration-file()
  (let ((file (format "%s/%s" *opx2-network-folder-work-path* *opx2-installations-paths-conf-file*))
	res
	(morelines t))
    (when (file-exists-p file)
      (with-temp-buffer
	(insert-file-contents file)
	(goto-char (point-min))
	(while morelines
	  (unless (fast-looking-at "#")
	    (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
		   (space (min (or (position ?\s line) (line-end-position))
			       (or (position ?\t line) (line-end-position)))))
	      (unless (= space (line-end-position))
		(let ((version (substring line 0 space))
;;		      (install-dir (replace-regexp-in-string "[ ]" "\\ " (trim-string (substring line (1+ space))) nil t)))
		      (install-dir (trim-string (substring line (1+ space)))))
		  (cond ((file-exists-p install-dir)
			 (push version res)
			 (push install-dir res))
			(t
			 (message "Ignoring version %s because directory '%s' does not exist." version install-dir)))))))
	  (setq morelines (= 0 (forward-line 1))))))
      (setq *opx2-installations-paths* (reverse res))))

(defun generate-runtime-functions ()
  (cond ((load-version-configuration-file)  
	 (define-key-after
	   global-map
	   [menu-bar plw]
	   (cons *planisware-menu-name* (make-sparse-keymap "plw"))
	   'tools )
	 
	 (do* ((i 0 (+ i 2))
	       (version (nth i *opx2-installations-paths*) (nth i *opx2-installations-paths*))
	       (path    (nth (1+ i) *opx2-installations-paths*) (nth (1+ i) *opx2-installations-paths*)))
	     ((>= i (length *opx2-installations-paths*)))
	   (let ((funname (format *runtime-function-name* version)))
	     ;; generate the run function
	     (with-temp-buffer
	       (insert (format *runtime-function-body*
			       funname
			       (file-name-as-directory path)))
	       (eval-buffer))
	     ;; menu bar
	     (define-key
	       global-map
	       (vector 'menu-bar 'plw (intern funname))
	       (cons (format *start-planisware-menu-item* version) (intern funname))))))
	(t
	 (message "%s file not found or incorrect !" *opx2-installations-paths-conf-file*))))

(generate-runtime-functions)
