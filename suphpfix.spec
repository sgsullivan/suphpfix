Summary: Corrects common issues that are often encountered when switching to CGI/FCGI/suPHP (with suexec enabled) on cPanel machines. Also has ability to backup changes for later restores.
Name: suphpfix
Version: 3.0.0
Release: 8
Group: System Tools/Utilities
URL: http://scripts.ssullivan.org/git
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
%setup -q -T -D

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
if [ -f /scripts/perlinstaller ]; then
  echo "Compiling perl-json.."
  /scripts/perlinstaller JSON > /dev/null 2>&1
  echo "Complete."
  echo "Compiling Unix::PID.."
  /scripts/perlinstaller Unix::PID > /dev/null 2>&1
  echo "Complete."
else
  echo "WARNING: /scripts/perlinstaller doesn't exist, is this a cPanel machine?" 2>&1
fi

%changelog
* Tue Jul 31 2012 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.0-8
- Code cleanup; use inheritance.
* Fri Jul 20 2012 Scott Sullivan <scottgregorysullivan@gmail.com> 3.0.0-7
- First public release. 
