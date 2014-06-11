Summary: Corrects common issues that are often encountered when switching to CGI/FCGI/suPHP (with suexec enabled) on cPanel machines. Also has ability to backup changes for later restores.
Name: suphpfix
Version: 3.0.9
Release: 1
Group: System Tools/Utilities
URL: http://ssullivan.org/git
License: GPL
Prefix: %{_prefix}
BuildRoot: %{_tmppath}/%{name}-%{version}-root
BuildArch:  noarch
AutoReqProv: no
AutoReq: 0
AutoProv: 0

%description
suphpfix (cPanel only) corrects common permission/ownership issues (as
well as some PHP setting issues) that are commonly encountered when
switching to CGI/FCGI/suPHP (with suexec enabled). suphpfix also has
the ability to restore cPanel accounts to the state they were in before
it made any changes. This is useful when users decide CGI/FCGI/suPHP
(with suexec enabled) is not for them and they wish to undo/revert all
changes made by suphpfix.

%prep
%setup -q -T -D -n suphpfix

%install
rm -fr ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix
mkdir -p ${RPM_BUILD_ROOT}/var/log/
mkdir -p ${RPM_BUILD_ROOT}/var/cache/suphpfix
mkdir -p ${RPM_BUILD_ROOT}/usr/bin

install -m700 suphpfix ${RPM_BUILD_ROOT}/usr/bin/suphpfix
install -m644 COPYING ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix/COPYING
install -m644 libs/API.pm ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix/API.pm
install -m644 libs/Prep.pm ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix/Prep.pm
install -m644 libs/Save.pm ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix/Save.pm
install -m644 libs/Restore.pm ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix/Restore.pm
install -m644 libs/Base.pm ${RPM_BUILD_ROOT}/usr/lib/suphpfix/suPHPfix/Base.pm

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/usr/bin/suphpfix
/usr/lib/suphpfix/suPHPfix/COPYING
/usr/lib/suphpfix/suPHPfix/API.pm
/usr/lib/suphpfix/suPHPfix/Prep.pm
/usr/lib/suphpfix/suPHPfix/Save.pm
/usr/lib/suphpfix/suPHPfix/Restore.pm
/usr/lib/suphpfix/suPHPfix/Base.pm

%post
if [ $1 == 1 ]; then
  if [ -f /scripts/perlinstaller ]; then
    echo "Compiling perl-json.."
    /scripts/perlinstaller JSON > /dev/null 2>&1
    echo "Complete."
  else
    echo "WARNING: /scripts/perlinstaller doesn't exist, is this a cPanel machine?" 2>&1
  fi
fi

%changelog
* Thu Jun 11 2014 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.9-1
- Globally ignore symlinks for security reasons.
* Thu Jan 02 2014 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.8-1
- Utilize S_IWGRP && S_IWOTH in prep routine for determining group or world write.
* Thu Sep 19 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.7-1
- Warn user when hardlinked file marked for modification.
* Fri Sep 13 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.6-1
- Report skipped hardlink files.
* Fri Sep 13 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.5-1
- Restore: Don't mess with htaccess if --ownerships-only or --perms-only given.
* Fri Sep 13 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.4-2
- Only compile perl-json on install not upgrade.
* Fri Sep 13 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.4-1
- Update help docs. Don't touch htaccess files if --ownerships-only or --perms-only given.
* Tue Aug 20 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.3-1
- Various code cleanups.
* Tue Aug 20 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.2-1
- Use pure perl in prep for chmods.
* Fri Aug 16 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.1-2
- Add options --ownerships-only & --perms-only. 
* Thu Aug 15 2013 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.1-1
- For security reasons, never adjust ownerships or permissions on a hard linked file.
* Tue Jul 31 2012 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.0-8
- Code cleanup; use inheritance.
* Fri Jul 20 2012 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.0-7
- First public release. 
