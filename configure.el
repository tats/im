;;; configure.el --- configure for Mule for Win32
;;; Author: yamagus@kw.netlaputa.or.jp (YAMAGUCHI, Shuhei)
;;; Created: Jul 23, 1997
;;; Updated: Sep 25, 1997
;;; Usage:
;;;  [Win95]
;;;   mule.exe -q -l ./configure.el -f configure -kill
;;;  [WinNT]
;;;   mulent.exe -batch -l ./configure.el -f configure
;;;
;;; Sep 18, 1997:
;;;   Merged with Mr. OKUNISHI's patch. (Thanks!)
;;; Sep 25, 1997:
;;;   Added SiteConfig version control.
;;;   Added modules detection.

;;;
;;; version
;;;
(defconst im_version "971025")
(defconst im_revised "Oct 25, 1997")

;;;
;;; install options (please check and edit config-def.el!!)
;;;
;;(require 'config-def)
(setq load-path (append (list ".") load-path))
(load "config-def" t)
(defvar prefix "c:/usr/local")
(defvar bindir (concat (file-name-as-directory prefix) "bin"))
(defvar libdir (concat (file-name-as-directory prefix) "lib"))
(defvar im_path_perl nil)		; auto-detected
(defvar perl-exec-name "perl")
(defvar im_path_siteperl nil)		; ???auto-detected???
(defvar im_db_type nil)			; auto-detected
(defvar install-after-configure t)
(defvar im-siteconfig-force-overwrite nil)
(defvar im-siteconfig-version-control t)

;;;
;;; const
;;;
(defconst im-executables-srcdir ".")
(defconst im-executables-dstdir ".")
(defconst im-executables-pat "^\\(im.*\\)\.in$")
(defconst im-libraries-srcdir "./IM.in")
(defconst im-libraries-dstdir "./IM")
(defconst im-libraries-pat "^\\(.*\.pm\\)\.in$")
(defconst im-siteconfig "SiteConfig")

(defconst replace-patterns '(("@im_version@" . (concat "version " im_version))
			     ("@im_revised@" . im_revised)
			     ("@im_path_perl@" . im_path_perl)
			     ("@im_db_type@" . im_db_type)
			     ("@prefix@" . prefix)
			     ("@libdir@" . libdir)))
(defconst config-tmp-buffer " *configure im*")
;;
(defvar im-executables nil)		; for executables detection
(defvar im-libraries nil)		; for libraries detection

;;;
;;; functions
;;;
(defun perl-examination (script)
  (let ((buf (get-buffer-create config-tmp-buffer)))
    (unwind-protect
	(save-excursion
	  (set-buffer buf)
	  (if (eq 0
		  (call-process im_path_perl nil t nil
				"-MConfig" "-e" script))
	      (progn
		(goto-char 1)
		(re-search-forward "[^\n\r]*" nil t)
		(buffer-substring 1 (point)))
	    nil))
      (kill-buffer buf))))

;; Derived from win32-script.el version 0.4.
(defvar script-process-pathext '(".com" ".exe" ".bat" ".cmd"))
(defun win32-openp (command-name)
  "Locate the full path name of external-command COMMAND-NAME."
  (interactive "sExternal-command: ")
  (catch 'tag
    (let (path)
      (if (file-name-absolute-p command-name)
	  (if (and (file-executable-p command-name)
		   (null (file-directory-p command-name)))
	      (throw 'tag command-name)
	    (mapcar
	     (lambda (suf)
	       (setq path (expand-file-name (concat command-name suf)))
	       (and (file-executable-p path)
		    (null (file-directory-p path))
		    (throw 'tag path)))
	     (if (null script-process-pathext)
		 '("")
	       script-process-pathext)))
	(mapcar
	 (lambda (dir)
	   (mapcar
	    (lambda (suf)
	      (setq path (expand-file-name (concat command-name suf) dir))
	      (and (file-executable-p path)
		   (null (file-directory-p path))
		   (throw 'tag path)))
	    (if (null script-process-pathext)
		'("")
	      (append (list "") script-process-pathext))))
	 exec-path))) nil))

(defun create-module (infile outfile)
  (let ((buf (get-buffer-create config-tmp-buffer)))
    (unwind-protect
	(save-excursion
	  (set-buffer buf)
	  (message "creating %s" out)
	  (insert-file-contents infile)
	  (mapcar
	   (lambda (pat)
	     (goto-char 1)
	     (while (search-forward (car pat) nil t)
	       (replace-match (eval (cdr pat)))))
	   replace-patterns)
	  (write-region (point-min) (point-max) outfile nil 1))
      (kill-buffer buf))))

(defun install ()
  ;; executables
  (or (file-directory-p bindir)
      (progn
	(message "create %s." bindir)
	(make-directory bindir t)))
  (mapcar
   (lambda (file)
     (let ((dst (concat (file-name-as-directory bindir) file)))
       (message "installing %s." dst)
       (copy-file (concat (file-name-as-directory im-executables-dstdir) file)
		  dst t)
       (set-file-modes dst ?\755)))
   im-executables)
  ;; libraries
  (let ((imlib (concat (file-name-as-directory im_path_siteperl) "IM")))
    (or (file-directory-p imlib)
	(progn
	  (message "create %s." imlib)
	  (make-directory imlib t)))
    (mapcar
     (lambda (file)
       (let ((dst (concat (file-name-as-directory imlib) file)))
	 (message "installing %s." dst)
	 (copy-file (concat (file-name-as-directory im-libraries-dstdir) file)
		    dst t)
	 (set-file-modes dst ?\644)))
     im-libraries))
  ;; SiteConfig
  (let ((imconf (concat (file-name-as-directory libdir) "im")))
    (or (file-directory-p imconf)
	(progn
	  (message "create %s." imconf)
	  (make-directory imconf t)))
    (let ((src (concat (file-name-as-directory "cnf.im") im-siteconfig))
	  (dst (concat (file-name-as-directory imconf) im-siteconfig)))
      (message "installing %s." dst)
      (if im-siteconfig-force-overwrite
	  (copy-file src dst t t)
	(if (file-exists-p dst)
	    (if im-siteconfig-version-control
		(copy-file src (concat dst "." im_version) t t)
	      (copy-file src (concat dst ".new") t t))
	  (copy-file src dst nil t)))
      (set-file-modes dst ?\644))))

(defun configure ()
  (catch 'tag
    ;; perl path
    (message "checking for perl...")
    (or im_path_perl
	(setq im_path_perl (win32-openp perl-exec-name))
	(progn (message "Please set im_path_perl manually.")
	       (throw 'tag nil)))
    (message "  (%s)" im_path_perl)
    ;; site_perl path
    (message "checking for siteperl...")
    (or im_path_siteperl
	(setq im_path_siteperl
	      (perl-examination "print $Config{installsitelib}")))
    (if (or (not im_path_siteperl) (string-match "^$"  im_path_siteperl))
	(progn (message "Please set im_path_siteperl manually.")
	       (throw 'tag nil)))
    (message "  (%s)" im_path_siteperl)
    ;; DB type
    (message "checking for DB type...")
    (or im_db_type
	(setq im_db_type
	      (perl-examination "BEGIN { @AnyDBM_File::ISA = qw(DB_File NDBM_File SDBM_File) }; use AnyDBM_File; $db = shift @AnyDBM_File::ISA; $db =~ s/_File//; print \"$db\";"))
	(progn (message "Please set im_db_type manually.")
	       (throw 'tag nil)))
    (message "  (%s)" im_db_type)
    ;; modify im executables
    (mapcar
     (lambda (in)
       (if (and (not (file-directory-p in))
		(string-match im-executables-pat in 0))
	   (let ((out (substring in 0 (match-end 1))))
	     (create-module
	      (concat (file-name-as-directory im-executables-srcdir) in)
	      (concat (file-name-as-directory im-executables-dstdir) out))
	     (setq im-executables (append im-executables (list out))))))
     (directory-files im-executables-srcdir))
    ;; modify im libraries
    (mapcar
     (lambda (in)
       (if (and (not (file-directory-p in))
		(string-match im-libraries-pat in 0))
	   (let ((out (substring in 0 (match-end 1))))
	     (create-module
	      (concat (file-name-as-directory im-libraries-srcdir) in)
	      (concat (file-name-as-directory im-libraries-dstdir) out))
	     (setq im-libraries (append im-libraries (list out))))))
     (directory-files im-libraries-srcdir))
    (if install-after-configure
	(install))))
