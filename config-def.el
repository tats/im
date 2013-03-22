;; config-def.el: user configuration for configure.el
;;
;; At least, please check <prefix>.
;;
;; For Win32 ActiveWare Perl users:
;;    Please set <im_path_siteperl>!!
;;    If perl.exe is "d:/local/perl/bin/perl.exe",
;;    "d:/local/perl/lib" is good.

;; Install prefix decides <bindir> and <libdir>.
;; (default is "c:/usr/local")
;(setq prefix "d:/local")

;; Where im executable modules is installed.
;; (default is "<prefix>/bin")
;(setq bindir "d:/local/bin")

;; Where im library file is installed.
;; SiteConfig is installed into <libdir>/im directory.
;; (default is "<prefix>/lib")
;(setq libdir "d:/local/lib")

;; Full pathname of perl executable.
;; nil means auto-detect.
;; (default is nil)
;(setq im_path_perl "d:/local/perl/bin/perl.exe")

;; Name of perl executable for auto detection.
;; Extention such as ".exe" is not needed.
;; (default is "perl")
;(setq perl-exec-name "perl5")

;; Where perl libraries of IM are installed.
;; *.pm files are installed into <im_path_siteperl>/IM directory.
;; nil means auto-detect.
;;   for Win32 ActiveWare Perl: Auto detection is not work, please set this!
;; (default is nil)
;(setq im_path_siteperl "d:/local/perl/lib")

;; Perl DB type.
;; nil means auto-detect.
;; (default is nil)
;(setq im_db_type "DB")

;; non-nil means install after configuration.
;; nil means configuration only.
;; (default is t)
;(setq install-after-configure nil)

;; Behavior when already exists <libdir>/im/SiteConfig.
;; non-nil means force overwrite <libdir>/im/SiteConfig.
;; nil means comply with <im-siteconfig-version-control>.
;; (default is nil)
;(setq im-siteconfig-force-overwrite t)

;; non-nil means SiteConfig is installed as <libdir>/im/SiteConfig.new.
;; nil means SiteConfig is installed as <libdir>/im/SiteConfig.<im_version>.
;; (default is t)
;(setq im-siteconfig-version-control nil)

(provide 'config-def)
