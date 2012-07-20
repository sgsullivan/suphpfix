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

package suPHPfix::Save;

use File::stat;
use Fcntl ':mode';
use File::Find ();
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

my %save_conf = (
	all_user_list => '/var/cache/suphpfix/backedupUserList.all',
);

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

sub do_save {
	my $self = shift;
	my $opts = shift;
	die "Base object not passed to do_save!" unless	$opts->{objects};
	$opts->{objects}->{base}->logger({ level => 'c', msg => 'param was not passed to do_save, cannot continue!' }) unless $opts->{param};	
	my $accntList = $opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/listaccts" });
	if ( $opts->{param} eq 'all' ) {
		### 'save-state' all users..
		if ( -e $save_conf{'all_user_list'} ) {
			unlink($save_conf{'all_user_list'});
		}
		my $account_counts = 0;
		for my $Cnt( @{$accntList->{acct}} ) {
			$account_counts++;
		}
		if ( $account_counts == 0 ) {
			$opts->{objects}->{base}->print_c({ msg => "You don't have any cPanel accounts; can't save-state!" });
		}
		my $saved_accounts = 0;
		for my $userCnt( @{$accntList->{acct}} ) {
			my $cpUser = $userCnt->{user};
			my $domain = $userCnt->{domain};
			$opts->{objects}->{base}->print_n({ msg => "Saving state for $cpUser ($saved_accounts/$account_counts)" });
			my $docRoot_details = $opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
			my $docRoot = $docRoot_details->{userdata}->{documentroot};
			$opts->{objects}->{base}->print_i({ msg => "$cpUser document root is: $docRoot" });
			my $base_conf_ref = $opts->{objects}->{base}->get_baseconf();
			my %base_conf = %$base_conf_ref;
			unless ( -d $base_conf{store_path} ) {
				mkdir $base_conf{store_path} ||	$opts->{objects}->{base}->logger->({ level => 'c', msg => "Failed to create $base_conf{'store_path'}; Got: $!" });
			}
			$opts->{objects}->{base}->print_i({ msg => "Recording the contents of $docRoot.." });
			our @docRoot_contents = ();
			sub wanted_to_save {
 				my ($dev,$ino,$mode,$nlink,$uid,$gid);
 				(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && push(@docRoot_contents,$name);
			}
			File::Find::find({wanted => \&wanted_to_save}, "$docRoot");
			my ($error,$err_msg) = $self->savePermOwner({ objects => $opts->{objects}, cpUser => "$cpUser", docroot => "$docRoot" }, \@docRoot_contents );	
			$saved_accounts++;
			if ( $error && $err_msg ) {
				$opts->{objects}->{base}->print_w({ msg => "Failed saving state for $cpUser; Details:\n$err_msg" });
			}
			else {
				$opts->{objects}->{base}->print_n({ msg => "Saved state for $cpUser ($saved_accounts/$account_counts)" });
			}
		}
		$opts->{objects}->{base}->print_n({ msg => "Completed. Saved state for $saved_accounts accounts." });
	}
	else {
		### 'save-state' chosen user..
		for my $userCnt( @{$accntList->{acct}} ) {
			if ( $userCnt->{user} eq $opts->{param} ) {
				my $cpUser = $userCnt->{user};
				my $domain = $userCnt->{domain};
				$opts->{objects}->{base}->print_n({ msg => "Saving state for $cpUser" });
				my $docRoot_details =
				$opts->{objects}->{api}->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
				my $docRoot = $docRoot_details->{userdata}->{documentroot};
				$opts->{objects}->{base}->print_i({ msg => "$cpUser document root is: $docRoot" });
				my $base_conf_ref = $opts->{objects}->{base}->get_baseconf();
				my %base_conf = %$base_conf_ref;
				unless ( -d $base_conf{'store_path'} ) {
					mkdir $base_conf{'store_path'} || $opts->{objects}->{base}->logger->({ level => 'c', msg => "Failed to create $base_conf{'store_path'}; Got: $!" });
				}
				$opts->{objects}->{base}->print_i({ msg => "Recording the contents of $docRoot.." });
				our @docRoot_contents = ();
				sub wanted_to_save_single {
					my ($dev,$ino,$mode,$nlink,$uid,$gid);
					(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && push(@docRoot_contents,$name);
				}
				File::Find::find({wanted => \&wanted_to_save_single}, "$docRoot");
				my ($error,$err_msg) = $self->savePermOwner({ objects => $opts->{objects}, cpUser => "$cpUser", docroot => "$docRoot" }, \@docRoot_contents );
				if ( $error && $err_msg ) {
					$opts->{objects}->{base}->print_w({ msg => "Failed saving state for $cpUser; Details:\n$err_msg" });
				}
				else {
					$opts->{objects}->{base}->print_n({ msg => "Completed. Saved state for $cpUser." });
				}
			}
		}
	}
}

sub savePermOwner {
	my $self = shift;
	my $opts = shift;
	die "savePermOwner was not passed objects!" unless $opts->{objects};
	my $files_ref = shift;

	my @files = @$files_ref;
	my %docRoot_Contents = (
		acct => {
			cpanelUser => [ ],
			file => [ ],
			perm => [ ],
			owner => [ ],
			roup => [ ],
		},
	 );
	my $file_counter = 0;
	for my $file ( @files ) {
		my $st = stat($file) or $opts->{objects}->{base}->print_w({ msg => "savePermOwner() failed to stat $file! Skipping..." }) && next;
		my $owner_uid = $st->[4];
		my $group_uid = $st->[5];
		unless ( $owner_uid =~ /[0-9]/ || $group_uid =~ /[0-9]/ ) {
			$opts->{objects}->{base}->print_w({ msg => "savePermOwner() ($file) owner_uid($owner_uid) or group_uid($group_uid) looks like garbage! Skipping..." }) && next;
		}
		my $mode = $st->mode || $opts->{objects}->{base}->print_w({ msg => "savePermOwner() can't get mode of $file! Skipping" }) && next;
		my $permissions = sprintf "%04o", S_IMODE($mode);
		my $user = getpwuid($owner_uid);
		my $group = getgrgid($group_uid);
		## Watch for nulls in JSON...
		unless ( defined($user) ) {
			$opts->{objects}->{base}->print_w({ msg => "savePermOwner() discovered user is null for $file! Skipping..." });
			next;	
		}
		unless ( defined($group) ) {
			$opts->{objects}->{base}->print_w({ msg => "savePermOwner() discovered group is null for $file! Skipping..." });
			next;
		}
		unless ( defined($permissions) ) {
			$opts->{objects}->{base}->print_w({ msg => "savePermOwner() discovered permissions are null for $file! Skipping..." });
			next;
		}
		unless ( defined($file) ) {
			$opts->{objects}->{base}->print_w({ msg => "savePermOwner() discovered file is null! Skipping..." });
			next;
		}
		push ( @{$docRoot_Contents{'acct'}{'cpanelUser'}}, $opts->{cpUser});
		push ( @{$docRoot_Contents{'acct'}{'file'}}, $file);
		push ( @{$docRoot_Contents{'acct'}{'perm'}}, $permissions);
		push ( @{$docRoot_Contents{'acct'}{'owner'}}, $user);
		push ( @{$docRoot_Contents{'acct'}{'group'}}, $group);
		$file_counter++;
	}
	require JSON;
	my $json = new JSON;
	my $docRoot_ContentsRef = \%docRoot_Contents;
	my $json_text = JSON->new->utf8(1)->pretty(0)->allow_nonref->encode($docRoot_ContentsRef);
	my $base_conf_ref = $opts->{objects}->{base}->get_baseconf();
	my %base_conf = %$base_conf_ref;
	my $json_file_path = $base_conf{'store_path'};
	$json_file_path .= "/datastore_suphpfix.";
	$json_file_path .= "$opts->{cpUser}.json";
	open FILE, ">$json_file_path" || $opts->{objects}->{base}->logger({ level => 'c', msg => "Could not open '$json_file_path': $!" });
	print FILE  $json_text, "\n";
	close(FILE);
	open BAKUSERS, ">>$save_conf{'all_user_list'}" || $opts->{objects}->{base}->logger({ level => 'c', msg => "Couldn't open file ($save_conf{'all_user_list'}); Got: $!" });
	print BAKUSERS $opts->{cpUser}, "\n";
	close(BAKUSERS);
	$opts->{objects}->{base}->print_n({ msg => "Recorded $file_counter file/dir permissions/ownerships for $opts->{cpUser}" });
}

sub get_saveconf {
	return \%save_conf;
}


1;
