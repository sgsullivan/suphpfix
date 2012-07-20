#!/usr/bin/env perl
# This file is part of suphpfix.

# suphpfix is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# suphpfix is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with suphpfix.  If not, see <http://www.gnu.org/licenses/>.
 
use strict;
use warnings;

package suPHPfix::Prep;

use File::Find (); 
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

#-------------------------------------------------------------------------------
# Constructor
#-------------------------------------------------------------------------------

sub new {
	my ($class) = @_;  
	my ($self) = {};
	bless ($self, $class);
	return $self;
}

#-------------------------------------------------------------------------------
# Methods
#-------------------------------------------------------------------------------

sub do_prep {
	my $self = shift;
	my $opts = shift;
	die "do_prep not passed objects" unless $opts->{objects};
	my $accntList = $opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/listaccts" });
	my $accnts_cnt = 0;
	for my $acct ( @{$accntList->{acct}} ) {
		$accnts_cnt++;
	};
	my %error_states = ( prep => {}, );
	if ( $opts->{param} eq 'all' ) {
		## 'Prep' all, 1 cPanel account.
		my $count = 0;
		if ( $accnts_cnt == 1 ) {
			$opts->{objects}->{base}->print_n({ msg => "Discovered one account." });
			my ($domain, $docroot_details, $user);
			for my $users( @{$accntList->{acct}} ) {
				$user = $users->{user};
				$domain = $users->{domain};
				$docroot_details =
				$opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
			};
			$opts->{objects}->{base}->print_n({ msg => "Preparing $user..." });
			my $docroot = $docroot_details->{userdata}->{documentroot};
			my $home_dir = $docroot_details->{userdata}->{homedir};
			my ($cmd_error,$msg) = $self->runCmds({ objects => $opts->{objects}, user => "$user", domain => "$domain", docroot => "$docroot", home_dir => "$home_dir" });
			if ( $cmd_error ) {
				$error_states{'prep'}{"$user"}{'msg'} = "$msg";
			}
			$count++;
			if ( $error_states{'prep'}{"$opts->{param}"}{'msg'} ) {
				my $err_msg = $error_states{'prep'}{"$opts->{param}"}{'msg'};
				$opts->{objects}->{base}->print_w({ msg => "Error(s) encountered while doing prep for $opts->{param}! Details below:\n$err_msg" });
			}
			else {
				$opts->{objects}->{base}->print_n({ msg => "Completed: $count / $accnts_cnt" });
			}
		}
		else {
			## 'Prep' all, more than 1 cpanel user.
			$opts->{objects}->{base}->print_n({ msg => "Discovered multiple accounts." });
			my ($domain,$user,$docroot,$home_dir);	
			my $count = 0;
			for my $userCnt( @{$accntList->{acct}} ) {
				$user = $userCnt->{user};
				$opts->{objects}->{base}->print_n({ msg => "Preparing $user..." });
				$domain = $userCnt->{domain};
				my $docroot_details =
				$opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
				$docroot = $docroot_details->{userdata}->{documentroot};
				$home_dir = $docroot_details->{userdata}->{homedir};
				my ($cmd_error,$msg) = $self->runCmds({ objects => $opts->{objects}, user => "$user", domain => "$domain", docroot => "$docroot", home_dir => "$home_dir" });
				if ( $cmd_error ) {
					$error_states{'prep'}{"$user"}{'msg'} = "$msg";
				}
				$count++;
				if ( $error_states{'prep'}{"$opts->{param}"}{'msg'} ) {
					my $err_msg = $error_states{'prep'}{"$opts->{param}"}{'msg'};
					$opts->{objects}->{base}->print_w({ msg => "Error(s) encountered while doing prep for $user! Details below:\n$err_msg" });
				}
				else {
					$opts->{objects}->{base}->print_n({ msg => "Completed: $count / $accnts_cnt" });
				}
			};
		}	
	}
	else {
		## Single user --prep
		$opts->{objects}->{base}->print_n({ msg => "Preparing $opts->{param}..." });
		my ($docroot, $domain, $home_dir);
		for my $userCnt( @{$accntList->{acct}} ) {
			if ( $userCnt->{user} eq $opts->{param} ) {
				$domain = $userCnt->{domain};
				my $domain_details =
				$opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
				$docroot = $domain_details->{userdata}->{documentroot};
				$home_dir = $domain_details->{userdata}->{homedir};
				my ($cmd_error,$msg) = $self->runCmds({ objects => $opts->{objects}, user => "$opts->{param}", domain => "$domain", docroot => "$docroot", home_dir => "$home_dir" });
				if ( $cmd_error ) {
					$error_states{'prep'}{"$opts->{param}"}{'msg'} = "$msg";
				}
				if ( $error_states{'prep'}{"$opts->{param}"}{'msg'} ) {
					my $err_msg = $error_states{'prep'}{"$opts->{param}"}{'msg'};
					$opts->{objects}->{base}->print_w({ msg => "Error(s) encountered while doing prep for $opts->{param}! Details below:\n$err_msg" });
				}
				else {
					$opts->{objects}->{base}->print_n({ msg => "Finished preping $opts->{param}!" });
				}
			}
		};
	}
	$self->cleanup({ objects => $opts->{objects} });
	$self->checkLogSize({ objects => $opts->{objects} });
}

sub runCmds {
	my $self = shift;
	my $opts = shift;

	die "runCmds not passed objects" unless $opts->{objects};	
	
	unless ( -d $opts->{docroot} ) {
		return(1,"Discovered document root ($opts->{docroot}) doesn't exist!")
	}
	if ( $opts->{docroot} !~ m/^\/home/ ) {
		return(1,"Discovered document root ($opts->{docroot}) for $opts->{user} doesn't start with /home*!");
	}	
	if ( $opts->{home_dir} !~ m/^\/home/ ) {
		return(1,"Discovered home dir ($opts->{home_dir}) for $opts->{user} doesn't start with /home*!");
	}
	$opts->{objects}->{base}->print_i({ msg => "Discovered document root: $opts->{docroot}" });

	$opts->{objects}->{base}->print_i({ msg => "Removing group and world write.." });
	system("find $opts->{docroot} -perm +022 -exec chmod go-w {} \\\;");

	##### Dir permissions
	$opts->{objects}->{base}->print_i({ msg => "Checking directory permissions.." });
	our @dirs = ();
	sub wanted_dirs {
		my ($dev,$ino,$mode,$nlink,$uid,$gid);
		(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && -d _ && push(@dirs, $name);
	}
	File::Find::find({wanted => \&wanted_dirs}, "$opts->{docroot}");
	for my $dir ( @dirs ) {
		chmod oct('0755'), $dir;
	}
	chmod oct('0750'), $opts->{docroot};
	chmod oct('0711'), $opts->{home_dir};

	##### Ownerships
	$opts->{objects}->{base}->print_i({ msg => "Setting ownerships to $opts->{user}:$opts->{user}.." });
	our @files = ();
	sub wanted_files {
	my ($dev,$ino,$mode,$nlink,$uid,$gid);
		(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && -f _ && push(@files, $name);
	}
	File::Find::find({wanted => \&wanted_files}, "$opts->{docroot}");
	for my $file ( @files ) {
		my ($login,$pass,$uid,$gid) = getpwnam($opts->{user}) or $opts->{objects}->{base}->logger({ level => 'c', msg => "Can't find $opts->{user} in /etc/passwd; Can't get numeric uids!" });
		chown($uid, $gid, $file);
	}
	for my $dir ( @dirs ) {
		my ($login,$pass,$uid,$gid) = getpwnam($opts->{user}) or $opts->{objects}->{base}->logger({ level => 'c', msg => "Can't find $opts->{user} in /etc/passwd; Can't get numeric uids!" });
		chown($uid, $gid, $dir);
	}
	my ($login,$pass,$uid,$gid) = getpwnam($opts->{user}) or return(1,"Can't find $opts->{user} in /etc/passwd; Can't get numeric uids!");
	chown($uid, $gid, $opts->{home_dir});
	my $nuid; #we dont want uid of nobody user.
	($login,$pass,$nuid,$gid) = getpwnam('nobody') or return(1,"Can't find nobody in /etc/passwd; Can't get numeric uids!");
	chown($uid, $gid, $opts->{docroot});

	# Files should be readable
	$opts->{objects}->{base}->print_i({ msg => "Ensuring files are readable.." });
	system("find $opts->{docroot} -type f -exec chmod ugo+r {} \\\;");

	# If no htscanner, comment out php tweaks from .htaccess files.
	unless ( $self->htscanner() ) {
		$opts->{objects}->{base}->print_i({ msg => "Commenting out php tweaks from .htaccess files.." });
		system("find $opts->{docroot} -name .htaccess -exec sed -i 's/^php_/#php_/g' {} \\\;");
	}
}

sub htscanner {
	my $self = shift;
	my $phpInfo = `php -i`;
	if ( $phpInfo =~ /htscanner/ ) {
		return 1;
	}
	return 0;
}

sub cleanup {
	my $self = shift;
	my $opts = shift;
	die "cleanup not passed objects!" unless $opts->{objects};
	$opts->{objects}->{base}->print_i({ msg => "Cleaning up..." });
	our @files = ();
	sub wanted {
		my ($dev,$ino,$mode,$nlink,$uid,$gid);
 		(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && push(@files,$name);
	}
	File::Find::find({wanted => \&wanted}, '/tmp/');
	for my $file ( @files ) {
		chmod oct('1777'), $file;
	}
	chmod oct('0700'), '/tmp/screens/S-root';
	chmod oct('0755'), '/tmp/screens';
}

sub checkLogSize {
	my $self = shift;
	my $opts = shift;
	die "checkLogSize not passed objects!" unless $opts->{objects};

	$opts->{objects}->{base}->print_i({ msg => "Checking size of logs..." });
	my $twoGBInBytes = '2147483648';
	my @log_files = ( '/usr/local/apache/logs/suphp_log', '/usr/local/apache/logs/error_log', '/usr/local/apache/logs/suexec_log', '/usr/local/apache/logs/access_log' );
	for my $logFile ( @log_files ) {
		if ( ! -e $logFile ) {
			$opts->{objects}->{base}->print_w({ msg => "$logFile doesn't exist." });
			next;
		}
		my $fileSize = -s $logFile;
		if ( $fileSize >= $twoGBInBytes ) {
			$opts->{objects}->{base}->print_w({ msg => "Log file ($logFile) is >= 2GB. This logfile should be cleared or rotated to avoid problems with the webserver. If logrotate is not configured, do the needful." });
		}
	}
}


1;
