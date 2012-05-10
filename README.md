user_cleanup
===

User homedir cleanup

Removes homedirs for invalid/disabled users.

:: Scans user dirs for invalid/disabled accounts. Renames dirs for deletion
:: after three months. For this to work:
:: - user dirs must have same name as user account
:: - you must have the ability to query AD
:: - you must have modify permissions to user dirs
:: - UnxUtils must be installed or in a subdir of the script location
:: - you will need to modify network paths to fit your environment