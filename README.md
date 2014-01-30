suphpfix 
========
suPHPfix (cPanel only) corrects common permission/ownership issues (as well as some PHP setting issues) that are 
commonly encountered when switching to CGI/FCGI/suPHP (with suexec enabled). suPHPfix also has the ability to 
restore cPanel accounts to the state they were in before it made any changes. This is useful when users 
decide CGI/FCGI/suPHP (with suexec enabled) is not for them and you wish to undo/revert all changes made by suPHPfix. 
By default due to security reasons, suPHPfix will not touch hardlinked files. If you want to modify hardlinked files 
anyways, please use the appropriate flags (described below). 

prep
===
1.) Sets public_html to 750 $cpuser:nobody

2.) Removes group and world write from all files

3.) Sets all directories to 755

4.) Sets /$home/$cpuser to 711

5.) Sets /$home/$cpuser/public_html/* to $cpuser:$cpuser

save-state
===
1.) Records recursive permissions/ownerships states of /$home/$cpuser/public_html 

restore-state
===
1.) Restores recursive permissions/ownerships states of /$home/$cpuser/public_html in accordance with the last save-state 

Examples:
========

Saving states
===
To save current permission/ownership states for all files/directories in every users WWW, run: 
 suphpfix --save-state all
 
To save current permission/ownership states for all files/directories in the 'test' cPanel accounts WWW, run: 
 suphpfix --save-state test

By default, this information will be stored in JSON files in /var/cache/suphpfix. 

Including Hardlinks: (Warning: Including hardlinks is not suggested)

To save current permission/ownership states for all files/directories in every users WWW, run: 
 suphpfix --save-state all --clobber-hard-links --yes-i-mean-it

To save current permission/ownership states for all files/directories in the 'test' cPanel accounts WWW, run: 
 suphpfix --save-state test --clobber-hard-links --yes-i-mean-it
 
Fixing Common suPHP Conversion Problems
===

To fix/prepare all cPanel accounts for the conversion to suPHP, you would run:
 suphpfix --prep all
 
To fix/prepare the 'test' cPanel account for the conversion to suPHP, you would run: 
 suphpfix --prep test
 
Ownerships Only:

To execute only the ownerships portion of the "prep" routine for all accounts: 
 suphpfix --prep all --ownerships-only
 
To execute only the ownerships portion of the "prep" routine for the 'test' account: 
 suphpfix --prep test --ownerships-only
 
Permissions Only:

To execute only the permissions portion of the "prep" routine for all accounts: 
 suphpfix --prep all --perms-only
 
To execute only the permissions portion of the "prep" routine for the 'test' account: 
 suphpfix --prep test --perms-only
 
Including Hardlinks: (Warning: Including hardlinks is not suggested)

To fix/prepare all cPanel accounts for the conversion to suPHP, you would run:
 suphpfix --prep all --clobber-hard-links --yes-i-mean-it
 
To fix/prepare the 'test' cPanel account for the conversion to suPHP, you would run: 
 suphpfix --prep test --clobber-hard-links --yes-i-mean-it
 
Ownerships Only:

To fix/prepare all cPanel accounts for the conversion to suPHP, you would run: 
 suphpfix --prep all --clobber-hard-links --yes-i-mean-it --ownerships-only
 
To fix/prepare the 'test' cPanel account for the conversion to suPHP, you would run: 
 suphpfix --prep test --clobber-hard-links --yes-i-mean-it --ownerships-only
 
Permissions Only:

To fix/prepare all cPanel accounts for the conversion to suPHP, you would run:
 suphpfix --prep all --clobber-hard-links --yes-i-mean-it --perms-only
 
To fix/prepare the 'test' cPanel account for the conversion to suPHP, you would run: 
 suphpfix --prep test --clobber-hard-links --yes-i-mean-it --perms-only
 
Restoring States
===

To restore all saved cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state all
 
To restore just the 'test' cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state liquidweb
 
Ownerships Only:

To execute only the ownerships portion of the "restore" routine for all accounts: 
 suphpfix --restore-state all --ownerships-only
 
To execute only the ownerships portion of the "restore" routine for the 'test' account: 
 suphpfix --restore-state test --ownerships-only
 
Permissions Only:

To execute only the permissions portion of the "restore" routine for all accounts: 
 suphpfix --restore-state all --perms-only
 
To execute only the permissions portion of the "restore" routine for the 'test' account: 
 suphpfix --restore-state test --perms-only
 
Including Hardlinks: (Warning: Including hardlinks is not suggested)

To restore all saved cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state all --clobber-hard-links --yes-i-mean-it
 
To restore just the 'test' cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state test --clobber-hard-links --yes-i-mean-it
 
Ownerships Only:

To restore all saved cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state all --clobber-hard-links --yes-i-mean-it --ownerships-only
 
To restore just the 'test' cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state test --clobber-hard-links --yes-i-mean-it --ownerships-only
 
Permissions Only:

To restore all saved cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state all --clobber-hard-links --yes-i-mean-it --perms-only
 
To restore just the 'test' cPanel accounts permissions/ownerships in WWW, run: 
 suphpfix --restore-state test --clobber-hard-links --yes-i-mean-it --perms-only
 
