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

package suPHPfix::Restore;

require JSON;

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

sub do_restore {
	my $self = shift;
	my $opts = shift;
	unless ( $opts->{param} || $opts->{objects} ) { 
		die "do_restore not passed param or objects!";
	}
	my $json = new JSON;
	my $save_confref = $opts->{objects}->{save}->get_saveconf();
	my %save_conf = %$save_confref;
	if ( $opts->{param} eq 'all' ) {
		## 'restore-state' all users..
		open FD, "$save_conf{'all_user_list'}" || $opts->{objects}->{base}->logger({ level => 'c', msg => "Can't open datastore file ($save_conf{'all_user_list'}): $!" });
		my @backedUpCPusers = <FD>;
		close FD;
		my $to_restore_total = scalar(@backedUpCPusers);
		my $restored_accounts = 1;
		for my $user ( @backedUpCPusers ) {
			chomp($user);
			my $cpUser = $user;
			$opts->{objects}->{base}->print_n({ msg => "Reverting suPHP fixes for $cpUser.." });
			### Let's make sure the cPanel account to be restored still exists on the server.
			unless ( $opts->{objects}->{api}->valid_user({ objects => $opts->{objects}, user => $cpUser }) ) {
				$opts->{objects}->{base}->print_w({ msg => "cPanel user '$cpUser' is no longer a valid user on this system; skipping..." });
				next;
			}
			my $base_conf_ref = $opts->{objects}->{base}->get_baseconf();
			my %base_conf = %$base_conf_ref;
			my $json_file_path = $base_conf{'store_path'};
			$json_file_path .= "/datastore_suphpfix.";
			$json_file_path .= "$cpUser.json";
			unless ( -e $json_file_path ) {
				$opts->{objects}->{base}->print_w({ msg => "Datastore file ($json_file_path) for $cpUser no longer exists. Please take another snapshot or restore datastore files from a previous snapshot. Skipping..." });
				next;
			}
			if ( -z $json_file_path ) {
				$opts->{objects}->{base}->print_w({ msg => "Datastore file ($json_file_path) for $cpUser exists but is empty. Please take another snapshot or restore datastore files from a previous snapshot. Skipping..." });
				next;
			}
			open FILE, "<$json_file_path";
			my $json_text = do { local $/; <FILE> };
			close(FILE);
			my $d_struct;
			eval {
				$d_struct = $json->allow_nonref->utf8->relaxed->decode($json_text);
			};
			if ($@) {
				$opts->{objects}->{base}->print_w({ msg => "Datastore file ($json_file_path) is not valid JSON. Please take another snapshot or restore datastore files from a previous snapshot. Skipping..." });
				next;
			}
			$opts->{objects}->{base}->print_i({ msg => "Reverting file/dir permissions/ownerships for $cpUser.." });
			my $restore_slot = 0;
			for my $restore_user ( @{$d_struct->{acct}->{cpanelUser}} ) {
				unless ( -e @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
					$opts->{objects}->{base}->print_w({ msg => "@{$d_struct->{acct}->{file}}[\"$restore_slot\"] no longer exists, skipping..." });
					$restore_slot++;
					next;
				}
				chmod oct(@{$d_struct->{acct}->{perm}}["$restore_slot"]), @{$d_struct->{acct}->{file}}["$restore_slot"];
				my ($uname, $upass, $uuid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) = getpwnam(@{$d_struct->{acct}->{owner}}["$restore_slot"]);
				my ($gname, $gpasswd, $ggid, $gmembers) = getgrnam(@{$d_struct->{acct}->{group}}["$restore_slot"]);
				chown($uuid, $ggid, @{$d_struct->{acct}->{file}}["$restore_slot"]);
				$restore_slot++;
			}
			if ( -d  @{$d_struct->{acct}->{file}}[0] && @{$d_struct->{acct}->{file}}[0] =~ /public_html/ ) {
				$opts->{objects}->{base}->print_i({ msg => "Uncommenting php tweaks for $user.." });
				system("find @{$d_struct->{acct}->{file}}[0] -name .htaccess -exec sed -i 's/^#php_/php_/g' {} \\\;");
			}
			else {
				$opts->{objects}->{base}->logger({ level => 'w', msg => "do_restore() base document root (@{$d_struct->{acct}->{file}}[0]) doesn't exist, or doesn't contain public_html.." });
			}
			$opts->{objects}->{base}->print_n({ msg => "suPHP fixes reverted for $cpUser! {Completed: $restored_accounts/$to_restore_total}" });
			$restored_accounts++;
		}
		$opts->{objects}->{base}->print_n({ msg => "suPHP fixes reverted for $to_restore_total accounts." });
	}
	else {
		## 'restore-state' single user..
		$opts->{objects}->{base}->print_n({ msg => "Reverting suPHP fixes for $opts->{param}.." });
		unless ( $opts->{objects}->{api}->valid_user({ objects => $opts->{objects}, user => $opts->{param} }) ) {
			$opts->{objects}->{base}->print_c({ msg => "cPanel user '$opts->{param}' is no longer a valid user on this system!" });
		}
		my $base_conf_ref = $opts->{objects}->{base}->get_baseconf();
 		my %base_conf = %$base_conf_ref;
		my $json_file_path = $base_conf{'store_path'};
		$json_file_path .= "/datastore_suphpfix.";
		$json_file_path .= "$opts->{param}.json";
		unless ( -e $json_file_path ) {
			$opts->{objects}->{base}->print_c({ msg => "Datastore file ($json_file_path) for $opts->{param} no longer exists. Please take another snapshot or restore datastore files from a previous snapshot." });
		}
		if ( -z $json_file_path ) {
			$opts->{objects}->{base}->print_c({ msg => "Datastore file ($json_file_path) for $opts->{param} exists but is empty. Please take another snapshot or restore datastore files from a previous snapshot." });
		}
		open FILE, "<$json_file_path";
		my $json_text = do { local $/; <FILE> };
		close(FILE);
		my $d_struct;
		eval {
			$d_struct = $json->allow_nonref->utf8->relaxed->decode($json_text);
		};
		if ($@) {
			$opts->{objects}->{base}->print_c({ msg => "Datastore file ($json_file_path) is not valid JSON. Please take another snapshot or restore datastore files from a previous snapshot." });
		}
		$opts->{objects}->{base}->print_i({ msg => "Reverting file/dir permissions/ownerships for $opts->{param}.." });
		my $restore_slot = 0;
		for my $restore_user ( @{$d_struct->{acct}->{cpanelUser}} ) {
			unless ( -e @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
				$opts->{objects}->{base}->print_w({ msg => "@{$d_struct->{acct}->{file}}[\"$restore_slot\"] no longer exists, skipping.." });
				$restore_slot++;
				next;
			}
			chmod oct(@{$d_struct->{acct}->{perm}}["$restore_slot"]), @{$d_struct->{acct}->{file}}["$restore_slot"];
			my ($uname, $upass, $uuid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) = getpwnam(@{$d_struct->{acct}->{owner}}["$restore_slot"]);
			my ($gname, $gpasswd, $ggid, $gmembers) = getgrnam(@{$d_struct->{acct}->{group}}["$restore_slot"]);
			chown($uuid, $ggid, @{$d_struct->{acct}->{file}}["$restore_slot"]);
			$restore_slot++;
		}
		if ( -d  @{$d_struct->{acct}->{file}}[0] && @{$d_struct->{acct}->{file}}[0] =~ /public_html/ ) {
			$opts->{objects}->{base}->print_i({ msg => "Uncommenting php tweaks for	$opts->{param}.." });
			system("find @{$d_struct->{acct}->{file}}[0] -name .htaccess -exec sed -i 's/^#php_/php_/g' {} \\\;");
		}
		else {
			$opts->{objects}->{base}->logger({ level => 'w', msg => "do_restore() base document root (@{$d_struct->{acct}->{file}}[0]) doesn't exist, or doesn't contain public_html.." });
		}
		$opts->{objects}->{base}->print_n({ msg => "suPHP fixes	reverted for $opts->{param}!" });
		$opts->{objects}->{base}->print_n({ msg => "suPHP fixes reverted for 1 accounts." });
	}
}

1;
