/*
 * fix-im.cmd  by fuji
 *
 * Created: 970908
 * Revised: 980902
 */

  ARG type .

  IF type ==''| ( type<>'REXX' & type <>'EXTPROC' ) THEN DO
     SAY 'Please specify fix type.'
     SAY '[usage] im-fix.cmd TYPE'
     SAY '	TYPE: "REXX" or "ExtProc".'
     EXIT 999
  END

  IF RxFuncQuery('SysLoadFuncs') THEN DO
     CALL RxFuncAdd "SysLoadFuncs","REXXUTIL","SysLoadFuncs"
     CALL SysLoadFuncs
  END
  CALL Time('R')
  EOL='0a'x

  SAY 'fix type:' type

  CALL SysFileTree 'im*.','f.','FO','*****','-----'
  DO i=1 TO f.0
     cmdfile=f.i'.cmd'
     rb=SysFileDelete(cmdfile)
     SAY 'creating' FileSpec('Name',cmdfile) '..'
     func = 'CALL' type '("'f.i'")'
     INTERPRET func
  END
  SAY Time('E')
EXIT


EXTPROC: PROCEDURE EXPOSE cmdfile EOL
PARSE ARG src
   head=LineIn(src)
   PARSE VAR head '#' '!' prog opt
   IF Pos('PERL',Translate(prog)) <>0 THEN opt = '-Sx' opt
   CALL CharOut cmdfile, 'extproc' prog opt ||EOL
   CALL CharOut cmdfile, head ||EOL
   DO WHILE Lines(src)
      line=LineIn(src)
      IF Pos('###DELETE-ON-INSTALL###', line) ==0
      THEN CALL CharOut cmdfile, line ||EOL
   END
RETURN

REXX: PROCEDURE EXPOSE cmdfile
   '@copy OS2\im.cmd' cmdfile '>nul 2>&1'
RETURN

/* End of procedure */
