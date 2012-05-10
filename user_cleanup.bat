:: user_cleanup.bat
::
:: Scans user dirs for invalid/disabled accounts. Renames dirs for deletion
:: after three months. For this to work:
:: - user dirs must have same name as user account
:: - you must have the ability to query AD
:: - you must have modify permissions to user dirs
:: - UnxUtils must be installed or in a subdir of the script location
:: - you will need to modify network paths to fit your environment


REM @echo off
:: cmd can't do many operations on URIs, so map user dir(s) to net drives here
net use e: \\XXXXX\em
net use z: \\XXXXX\usihomedir$\usihomedir
:: userdirs is a space-separated list of user directories
set userdirs=e:\users\ z:\

:: get working directory
for /f %%A in ('pwd') do (
	set bat_dir=%%A
)
if not exist %bat_dir%\removed_users mkdir removed_users

:: back up current path, update to include UnxUtils
set orig_path=%path%
set path=%path%;%bat_dir%\..\unxutils
set logfile="%bat_dir%\user_cleanup.log"
echo beginning cleanup > %logfile%

call :getDate
set record="%bat_dir%\removed_users\%year%%month%.txt"
call :rename
call :delete

echo cleanup complete >> %logfile%

:: reset path to original and clean up variables
set path=%orig_path%
set month=
set del_month=
set bat_dir=
set userdirs=
set record=
set logfile=
goto :EOF

:rename
SET string=""
SETLOCAL ENABLEDELAYEDEXPANSION
:: for all user dirs...
for %%D in (%userdirs%) do (
	chdir /d %%D
	:: for each directory...
	FOR /F %%I in ('dir /b /ad') DO (
		set dir=%%I
		:: if dir hasn't been marked already...
		if "!dir:~0,1!" NEQ "_" (
			set user=Not Found
			(SET string=%%I)
			:: query AD for user
			FOR /F %%U in ('dsquery user -name %%I') DO (
				set user=%%U
			)
			IF "!user!" == "Not Found" (
				:: user doesn't exist. mark for deletion
				echo !string! >> %record%
				echo renaming %%D%%I	"_%%I %del_month%"	-no account- >> %logfile%
				ren %%I "_%%I %del_month%"
			) ELSE (
				:: user exists. check status
				FOR /F "tokens=2" %%B in ('dsget user -L !user! -disabled') DO (
					IF "%%B" == "yes" (
						:: user account is disabled. mark for deletion
						SET "string=!string!	!user!"
						CALL :getParams !user! desc
						CALL :getParams !user! memberof
						echo !string! >> %record%
						echo renaming %%D%%I	"_%%I %del_month%"	-disabled- >> %logfile%
						ren %%I "_%%I %del_month%"
					)
				)
			)
		)
	)
)
ENDLOCAL
SET string=
SET user=
GOTO :EOF

:getParams
:: collect user information for logging
SET user=%1
SET param=-%2
FOR /F "tokens=1* delims= " %%A in ('dsget user !user! %param%') DO (
	IF "%%A" NEQ "%2" IF "%%A" NEQ "dsget" (
		IF "!param!"=="-memberof" (
			(SET string=!string!%%A;)
		) ELSE IF "!param!"=="-desc" (
			(SET string=!string!	%%A %%B	)
		)
	)
)
GOTO :EOF

:delete
for %%D in (%userdirs%) do (
	chdir /d %%D
	:: find all dirs matching "_username MMM"
	for /f "tokens=*" %%A in ('find . -iname "_* %month%" -maxdepth 1') do (
		echo deleting %%D%%A >> %logfile%
		:: delete dir
		rm -rf "%%A"
	)
)
set txt=
goto :EOF

:getDate
:: backup date format
reg copy "HKCU\Control Panel\International" "HKCU\Control Panel\International-Temp" /f
:: standardize date format
reg add "HKCU\Control Panel\International" /v sShortDate /d "yyyy-MMM" /f

:: get current month and year
for /f "tokens=2,3 delims=- " %%a in ('date /t') do (
set year=%%a
set month=%%b
)

:: determine month to delete user dirs
goto %month%
:Jan
set del_month=APR
goto end
:Feb
set del_month=MAY
goto end
:Mar
set del_month=JUN
goto end
:Apr
set del_month=JUL
goto end
:May
set del_month=AUG
goto end
:Jun
set del_month=SEP
goto end
:Jul
set del_month=OCT
goto end
:Aug
set del_month=NOV
goto end
:Sep
set del_month=DEC
goto end
:Oct
set del_month=JAN
goto end
:Nov
set del_month=FEB
goto end
:Dec
set del_month=MAR
goto end

:END
:: revert date format
reg copy "HKCU\Control Panel\International-Temp" "HKCU\Control Panel\International" /f
goto :EOF
