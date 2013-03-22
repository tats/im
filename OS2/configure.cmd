/*
 *                configure.cmd for IM
 *
 *      Copyright (C) 1997  Internet Message Group
 *
 *         This [OS/2] REXX procedure conforms
 *        GNU GENERAL PUBLIC LICENSE Version 2.
 *
 *
 * Author:  OKUNISHI Fujikazu <fuji0924@mbox.kyoto-inet.or.jp>
 *          KONDO Hiroyasu    <hirokon@homi.toyota.aichi.jp>
 * Maintainer: (null ;-)
 * Created: Jun 29,1997
 * Revised: Jan 28,1998
 *
 * Requirements:
 *   HPFS partition :-)
 *   GNU File Utilities (gnufutil.zip)
 *   GNU sed (gnused.zip)
 *   GNU strip (emx09c/gnudev1.zip)
 *
 * Hall of fame:
 *   SASAKI Osamu    <s-osamu@ppp.bekkoame.or.jp>
 *   OHMORI Norihito <ohmori@p.chiba-u.ac.jp>
 */
Call Time('R')
  Trace Off
  '@echo off'

  Call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
  Call SysLoadFuncs

  Parse Arg Argv.1 Argv.2 Argv.3 Argv.4 Argv.5 Argv.6 .
/* ----------------------------------------------------------------- *
 *		set minimum variables (1)
 * ----------------------------------------------------------------- */
  TAB = D2C(9)
  InFile     = '.\configure.in'
  SiteConfig = 'SiteConfig'
  CacheFile  = '.\os2config.cache'
  TemplateCMD= '.\OS2\im.cmd'
  InstallCMD = '.\install-os2.cmd'
  os2env='OS2ENVIRONMENT'; pl5_env='PERL5LIB'; pl_env='PERLLIB'
  Nkf        = SysSearchPath('PATH','nkf.exe')
  DelCR      = SysSearchPath('PATH','delcr.exe')
  Parse Source . . thiscmd
   thiscmd = Filespec('Name',thiscmd)    /* OS/2 REXX only */

/* ------------------------------------------------------------------ *
 *		Arg item syntax check
 * ------------------------------------------------------------------ */
  ConfVal.1.0='--autoconf';  ConfVal.1.1=''
  ConfVal.2.0='--dbtype';  ConfVal.2.1=''
  ConfVal.3.0='--drive';  ConfVal.3.1=''
  ConfVal.4.0='--clean';  ConfVal.4.1=''
  ConfVal.5.0='--debug';  ConfVal.5.1=''
  ConfVal.6.0="--help"

  Do lp = 1 To 5
    If Argv.lp = '' Then Leave
    Do lp2 = 1 To 7
      If lp2 = 7
      Then Do
         Say Argv.lp '???'
         Signal USAGE
      End
      match = Compare(ConfVal.lp2.0, Argv.lp)
      If match = 0
      Then Do
         If lp2 = 6 Then Signal USAGE
         ConfVal.lp2.1='yes'
         Leave
      End
      If (match > Length(ConfVal.lp2.0)) & (Substr(Argv.lp, match,1) = '=')
      Then Do
         ConfVal.lp2.1=Substr(Argv.lp, match+1)
         Leave
      End
    End
  End

  AutoConf = Translate(ConfVal.1.1)
    If AutoConf <> 'YES' Then AUTOCONF = 'NO'
  DbType = Translate(ConfVal.2.1)
    If DbType=''|DBTYPE='YES' Then DBTYPE='DB'
  Drive = ConfVal.3.1
    If Drive=''|Translate(Drive) ='YES'
      Then Drive=''
      Else TargetDrive = Left(Drive,1) || ':' /* case '--drive=(e|e:\)' */
  If Translate(ConfVal.4.1) = 'YES' Then Signal CLEAN
  If Translate(ConfVal.5.1) = 'YES' Then dbg=1; Else dbg=0
  Call DMSG(0 'AUTODETECT='autoconf', DBTYPE='dbtype', DRIVE='drive)

/* ----------------------------------------------------------------- *
 *		cachefile exist ?
 * ----------------------------------------------------------------- */
  If Stream(CacheFile,'C','QUERY EXIST') <> ''
  Then Do
     Say 'use sed script' CacheFile
     Signal CREATE
  End
  Call DMSG(0 'NOT exist' CacheFile)

/* ----------------------------------------------------------------- *
 *		set variables (2)   CASE: no cachefile
 * ----------------------------------------------------------------- */
  DefaultPerl5   = 'perl5'
  DefaultChmod   = 'chmod'
  DefaultCp      = 'cp'
  DefaultLn      = 'cp'
  DefaultMkdir   = 'mkdir'
  DefaultRm      = 'rm'
  DefaultStrip   = 'strip'
  DefaultInstall = 'install'
  Srcdir         = '.'
  BootDrive      = Left(Value('USER_INI',,os2env),2)
  If Drive='' Then TargetDrive = SetPathname(TargetDrive BootDrive)
  DefaultPrefix     = TargetDrive || '/usr/local'
  DefaultBindir     = DefaultPrefix || '/bin'
  DefaultLibdir     = DefaultPrefix || '/lib'
  DefaultMandir     = DefaultPrefix || '/man'
  DefaultExecprefix = DefaultPrefix
  DefaultSiteperl = GetFromEnv(pl5_env pl_env PerlLibPath)
  If DefaultSiteperl=''
    Then DefaultSiteperl= DefaultPrefix || '/lib/perl5/site_perl'

/* ----------------------------------------------------------------- *
 *		set pathname
 * ----------------------------------------------------------------- */
  Prefix      = SetPathname(PREFIX DefaultPrefix)
  Bindir      = SetPathname(BINDIR DefaultBindir)
  Libdir      = SetPathname(LIBDIR DefaultLibdir)
  Mandir      = SetPathname(MANDIR DefaultMandir)
  Execprefix  = SetPathname(EXECPREFIX DefaultExecprefix)
  Siteperl    = SetPathname(SITEPERL DefaultSiteperl)

/* ----------------------------------------------------------------- *
 *		get progname
 * ----------------------------------------------------------------- */
  Perl5Prog   = ProgPath(PERL DefaultPerl5)
  ChmodProg   = ProgPath(CHMOD DefaultChmod)
  CpProg      = ProgPath(CP DefaultCp)
  LnProg      = ProgPath(LN DefaultLn)
  MkdirProg   = ProgPath(MKDIR DefaultMkdir)
  RmProg      = ProgPath(RM DefaultRm)
  StripProg   = ProgPath(STRIP DefaultStrip)
  InstallProg = ProgPath(INSTALL DefaultInstall)

/* ----------------------------------------------------------------- *
 *		generate sed script
 *			`@im_version@' `@im_revised@'
 * ----------------------------------------------------------------- */
/* i: 1-2 */
  str.0=2;  str.1='im_version';  str.2='im_revised'
  Do i=1 To str.0
     Do While Lines(InFile)
        Parse Value Linein(InFile) With val.i '="' val.i.i '"' .
        If val.i <> str.i
        Then Iterate
        Else SedScr.i ='s|@' || str.i || '@|' || val.i.i || '|'
         Leave
     End
     Call DMSG(0 SedScr.i)
  End

/* i: 3-20 */
  SedScr.3 ='s|@im_path_perl@|'Perl5Prog'|'
  SedScr.4 ='s|@im_path_chmod@|'ChmodProg'|'
  SedScr.5 ='s|@im_path_cp@|'CpProg'|'
  SedScr.6 ='s|@im_path_ln@|'LnProg'|'
  SedScr.7 ='s|@im_path_mkdir@|'MkdirProg'|'
  SedScr.8 ='s|@im_path_rm@|'RmProg'|'
  SedScr.9 ='s|@im_path_strip@|'StripProg'|'
  SedScr.10='s|@srcdir@|'Srcdir'|'
  SedScr.11='s|@INSTALL@|'InstallProg'|'
  SedScr.12='s|@prefix@|'Prefix'|'
  SedScr.13='s|@bindir@|'Bindir'|'
  SedScr.14='s|@libdir@|'Libdir'|'
  SedScr.15='s|@mandir@|'Mandir'|'
  SedScr.16='s|@exec_prefix@|'ExecPrefix'|'
  SedScr.17='s|@im_path_siteperl@|'SitePerl'|'

  SedScr.18='s|@im_rpop@|-m 555|'
  SedScr.19='s|@im_db_type@|'DBTYPE'|'
  SedScr.20='s/@im_file_attr@/O_RDWR|O_CREAT|O_EXCL|O_BINARY/'
  i=20

/* generate */
  Say 'generating `' || CacheFile || "' ..."
  Do n = 1 to i
     Call LineOut CacheFile, SedScr.n
     Call DMSG(0 SedScr.n)
  End
  Call LineOut CacheFile   /* close */
  Say 'done.'

/* ----------------------------------------------------------------- *
 *		generate `install-os2.cmd'
 * ----------------------------------------------------------------- */
  rc = SysFileDelete(InstallCMD)  /* clean */
  Imdir    = Translate(Siteperl,'\','/') || '\IM\'
  Mandir   = Translate(Mandir,'\','/') || '\man1'  /* $MANDIR/man1 ? */
  Bindir   = Translate(Bindir,'\','/') || '\'
  Imlibdir = Translate(Libdir,'\','/') || '\im\'
  Call DMSG(0 Imdir Mandir Bindir Imlibdir)
 
  str.0 = 5
  str.1 = '@rem !!!!! auto-generated by' thiscmd '!!!!!'
  str.2 = 'xcopy /o .\IM\*.pm' Imdir        /* IM */
  str.3 = 'xcopy /o .\im*.'    Bindir       /* script */
  str.4 = 'xcopy /o .\im*.cmd' Bindir       /* cmd */
  str.5 = 'xcopy /o/p .\cnf.im\'SiteConfig Imlibdir  /* SiteConfig */
      i = str.0

  If Nkf = '' Then Signal USEXCOPY
  Call SysFileTree Mandir,'d.','DO'   /* 'D' directory */
   If d.0 = '0' Then Signal USEXCOPY
  Call SysFileTree '.\man\im*','man.','FO'
   If man.0 <> '0' Then
     Do n = 1 to man.0
        i = i +1; str.0 = str.0 +1
        Call DMSG(0 man.n)
        man.n = Filespec('Name',man.n)
        str.i = Nkf '-s .\man\' || man.n '>' Mandir || '\' || man.n
     End
  Signal MAKECMD

USEXCOPY:   /* CASE: (nkf.exe not found) | ($MANDIR/man1 not found) */
  str.0 = str.0 +1
  str.6 = 'xcopy /o .\man\*' Mandir || '\'  /* manpage */

MAKECMD:
  Say 'generating `' || InstallCMD || "' ..."
  Do j = 1 to str.0
    Call LineOut InstallCMD, str.j
    Call DMSG(0 str.j)
  End
  Call LineOut InstallCMD   /* close */
  Say 'done.'


/* ----------------------------------------------------------------- *
 *		create target files after analysis (by hirokon)
 * ----------------------------------------------------------------- */
CREATE:
  rc= SysMkDir('.\IM')
  'sed -f' CacheFile TemplateCMD || '.in>' TemplateCMD

  Do While Lines(InFile)
	ReadRecord = Linein(InFile)
	x = Pos('AC_OUTPUT',ReadRecord)
	If x>0 Then Leave
  End

  s = Pos('(',ReadRecord) + 1

  If Right(ReadRecord,1)='\' Then Do
	t = SubStr(ReadRecord,s)
	t = Strip(t,'T','\')
	ao = t
  End

  Do While Lines(InFile)
	ReadRecord = Linein(InFile)
	t = Strip(ReadRecord,'B',TAB)
	l = Right(t,1); lb=Substr(Reverse(t),2,1)
	If l = '\' | l = ')' | lb = ')'
	  Then Do
		t = Strip(t,'T',l)
		ao = ao t
	  End
	  Else Do
		Call DMSG(1 'Error: cannot analyze' InFile)
		Exit 2
	  End
	If l = ')' Then Leave
  End
  ao = Strip(ao,'T',')')

  Do i = 1 To Words(ao)
	ac_output.i = Translate(Word(ao,i),'\','/')
	If ac_output.i = ',' Then comma = i
  End
  ac_output.0 = i - 1
  If ac_output.0 = 0 Then Exit

  Do i = 1 To comma - 1
	Parse VAR ac_output.i targetFile.i ':' srcFile.i 
	Say 'creating' targetFile.i '...'
	'sed -f' CacheFile srcFile.i '>' targetFile.i
	If Left(targetFile.i,2) ='im'
	Then Do
	   cmd.i= targetFile.i || '.cmd'
	   'copy' TemplateCMD cmd.i '>nul'
	   If DelCR<>''
	   Then Do
	     DelCR targetFile.i '>nul'
	     rc = SysFileDelete(targetFile.i || '.bak')
	   End
	End
	/*Say 'done.'*/
  End
  If DelCR<>'' Then Delcr './IM/*.pm >nul & rm -rf ./IM/*.pm.bak'
Call DMSG(0 'time:'Time('E'))

/* ----------------------------------------------------------------- *
 *		install now ?
 * ----------------------------------------------------------------- */
   '@echo on'
   Say 'install NOW ? (Yes/No)'
   Pull answer .
   If answer = 'YES'
     Then '@call' InstallCMD
     Else Say 'To install, type "'InstallCMD'[RET]".'
Exit

/* ----------------------------------------------------------------- *
 *		clean w/o Makefile
 * ----------------------------------------------------------------- */
CLEAN:
   target = './im*. ./im*.cmd ./OS2/im.cmd' CacheFile InstallCMD
   'rm -rf' target
   rc = SysMkdir('.\IM')
Exit

/* ----------------------------------------------------------------- *
 *		get value from environment variable
 * ----------------------------------------------------------------- */
GetFromEnv: Procedure  Expose os2env
  Parse Arg env.1 env.2 dst .
  dir = '' /*initialize*/
  Do i =1 to 2
     d.i = Value(env.i,,os2env)
     If d.i = '' Then Iterate
     Do Until Length(d.i) = 0
        Parse Value d.i with dir ';' d.i
        If dir <> '.' Then Leave
     End
     Leave
  End
  Call DMSG(0 dst'='dir)
  Return Translate(dir,'/','\')

/* ----------------------------------------------------------------- */
/*		`configure.cmd(pmmule2.3)'  `Makeos2.cmd'(jweblint-97)
 * ----------------------------------------------------------------- */
ProgPath: Procedure  Expose AUTOCONF
  Parse Arg ProgName DefaultProg .
  If AUTOCONF='YES'
  Then ProgPath = SysSearchPath('PATH',DefaultProg || '.exe')
  Else Do  /* AUTOCONF=NO */
    Do Forever
       Say ProgName "program name ? (default =" DefaultProg ")"
       Parse Pull InProg .
       If InProg = ""
       Then Do
           InProg = DefaultProg
           Cursor = SysCurPos( Word( SysCurPos( ), 1 ) -1, 0 )
           Say InProg
       End
       ChkExt = InProg
       Parse Upper Var ChkExt ChkExt
       If Pos( ".EXE", ChkExt ) = 0 Then InProg = Insert(InProg, ".exe")
       Drop ChkExt
       ProgPath = SysSearchPath("PATH", InProg )
       If ProgPath = ""
       Then Do
           Say ProgName "program `"InProg"' Not Found."
           Exit
       End
       Else Do
            Say ProgName "executable `"ProgPath"'. Found."
            Say "Use this program ? (Yes/No, default = Yes )"
            Pull Anser .
            If (Anser = "") | (Anser = "YES" )
            Then Do
                Cursor = SysCurPos( WORD( SysCurPos( ), 1 ) -1, 0 )
                Say "Yes"
               Leave
            End
       End
    End
  End /* AUTOCONF=YES */
  ProgPath = Translate(ProgPath, Xrange('a','z'), Xrange('A','Z'))
  Return Translate(ProgPath,'/','\')

/* ----------------------------------------------------------------- */
/*		`configure.cmd(pmmule2.3)'  `Makeos2.cmd'(jweblint-97)
 * ----------------------------------------------------------------- */
SetPathname: Procedure  Expose AUTOCONF
  Parse Arg PathName DefaultPath .
   If AUTOCONF='YES' Then InPath = DefaultPath;  Else Do
   Do Forever
      Say "input path name for `" || PathName || "'? (default =" DefaultPath ")"
      Parse Pull InPath .
      If InPath = '' Then
         Do
           InPath = DefaultPath
           Cursor = SysCurPos( Word( SysCurPos( ), 1 ) -1, 0 )
           Say InPath
         End
      ChkExt = InPath
      Drop ChkExt
      Say '`' || InPath || "' selected for" PathName || '.'
      Say "It's OK? (Yes/No, default = Yes )"
      Pull Anser .
      If (Anser = '') | (Anser = 'YES' ) Then
         Do
           Cursor = SysCurPos( WORD( SysCurPos( ), 1 ) -1, 0 )
           Say 'Yes'
          Leave
         End
   End
   End /* AUTOCONF=YES */
   InPath = Translate(InPath, Xrange('a','z'), Xrange('A','Z'))
  Return Translate(InPath,'/','\')

/* ----------------------------------------------------------------- *
 *		debug message
 * ----------------------------------------------------------------- */
DMSG:
 Parse Arg arg1 arg2
  If dbg=1 | arg1=1
    Then Call LineOut STDERR,arg2
  Return

/* ----------------------------------------------------------------- *
 *		Display usage message
 * ----------------------------------------------------------------- */
USAGE:
  Say 'Usage:' thiscmd 'CONFIGURATION [-OPTION[=VALUE] ...]'
  Say
  Say 'Set configration and installation parameters for IM.'
  Say 'CONFIGURATION specifies the operating system to build for.'
  Say
  Say ConfVal.1.0||'		skip manual configuration'
  Say ConfVal.2.0||'		set Perl DB Type (Default=DB)'
  Say ConfVal.3.0||'			force target drive to install'
  Say ConfVal.4.0||'			clean'
  Say ConfVal.5.0||'			debug mode (to STDERR)'
  Say
  Say 'for example:'
  Say '	' thiscmd ConfVal.1.0
  Say '	' thiscmd ConfVal.2.0 || '=SDBM'
  Say '	' thiscmd ConfVal.1.0 || '=yes' ConfVal.3.0 || '=e:'
  Say '	' thiscmd ConfVal.1.0 || '=yes' ConfVal.2.0 || '=SDBM'

/* End of procedure */
