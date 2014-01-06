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
use parent 'suPHPfix::API';

require JSON;

#-------------------------------------------------------------------------------
# Methods
#-------------------------------------------------------------------------------

sub do_restore {
  my $self = shift;
  my $opts = shift;
  unless ( $opts->{param} ) { 
    $self->logger({ level => 'c', msg => 'do_restore not passed param!'});
  }
  my $json = new JSON;
  my $base_conf_ref = $self->get_baseconf();
  my %base_conf = %$base_conf_ref;


  if ( $base_conf{ownerships_only} ) {
    $self->logger({ level => 'n', msg => "Restoring only ownerships per user request!" });
  }
  elsif ( $base_conf{perms_only} ) {
    $self->logger({ level => 'n', msg => "Restoring only permissions per user request!" });
  }


  if ( $opts->{param} eq 'all' ) {
    ## 'restore-state' all users..
    open FD, "$base_conf{'all_user_list'}" || $self->logger({ level => 'c', msg => "Can't open datastore file ($base_conf{'all_user_list'}): $!" });
    my @backedUpCPusers = <FD>;
    close FD;
    my $to_restore_total = scalar(@backedUpCPusers);
    my $restored_accounts = 1;
    for my $user ( @backedUpCPusers ) {
      chomp($user);
      my $cpUser = $user;
      $self->print_n({ msg => "Reverting suPHP fixes for $cpUser.." });
      ### Let's make sure the cPanel account to be restored still exists on the server.
      unless ( $self->valid_user({ user => $cpUser }) ) {
        $self->print_w({ msg => "cPanel user '$cpUser' is no longer a valid user on this system; skipping..." });
        next;
      }
      my $json_file_path = $base_conf{'store_path'};
      $json_file_path .= "/datastore_suphpfix.";
      $json_file_path .= "$cpUser.json";
      unless ( -e $json_file_path ) {
        $self->print_w({ msg => "Datastore file ($json_file_path) for $cpUser no longer exists. Please take another snapshot or restore datastore files from a previous snapshot. Skipping..." });
        next;
      }
      if ( -z $json_file_path ) {
        $self->print_w({ msg => "Datastore file ($json_file_path) for $cpUser exists but is empty. Please take another snapshot or restore datastore files from a previous snapshot. Skipping..." });
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
        $self->print_w({ msg => "Datastore file ($json_file_path) is not valid JSON. Please take another snapshot or restore datastore files from a previous snapshot. Skipping..." });
        next;
      }
      $self->print_i({ msg => "Reverting file/dir permissions/ownerships for $cpUser.." });
      my $restore_slot = 0;
      for my $restore_user ( @{$d_struct->{acct}->{cpanelUser}} ) {
        unless ( -e @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
          $self->print_w({ msg => "@{$d_struct->{acct}->{file}}[\"$restore_slot\"] no longer exists, skipping..." });
          $restore_slot++;
          next;
        }

        if ( $base_conf{'clobber_hlinks'} ) {
          if ( ! -d @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = $self->get_stat({ name => @{$d_struct->{acct}->{file}}["$restore_slot"] });
            if ( $nlink > 1 ) {
              $self->print_w({ msg => "Clobbering hard link file @{$d_struct->{acct}->{file}}[\"$restore_slot\"] per user request!" });
            }
          }
        }
        else {
          if ( ! -d @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = $self->get_stat({ name => @{$d_struct->{acct}->{file}}["$restore_slot"] });
            if ( $nlink > 1 ) {
              $self->print_i({ msg => "Skipping hard link file @{$d_struct->{acct}->{file}}[$restore_slot].." });
              $restore_slot++;
              next;
            }
          }
        }

        if ( $base_conf{ownerships_only} ) {
          my ($uname, $upass, $uuid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) = getpwnam(@{$d_struct->{acct}->{owner}}["$restore_slot"]);
          my ($gname, $gpasswd, $ggid, $gmembers) = getgrnam(@{$d_struct->{acct}->{group}}["$restore_slot"]);
          chown($uuid, $ggid, @{$d_struct->{acct}->{file}}["$restore_slot"]);
          $restore_slot++;
        }
        elsif ( $base_conf{perms_only} ) {
          chmod oct(@{$d_struct->{acct}->{perm}}["$restore_slot"]), @{$d_struct->{acct}->{file}}["$restore_slot"];
          $restore_slot++;
        }
        else {
          chmod oct(@{$d_struct->{acct}->{perm}}["$restore_slot"]), @{$d_struct->{acct}->{file}}["$restore_slot"];
          my ($uname, $upass, $uuid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) = getpwnam(@{$d_struct->{acct}->{owner}}["$restore_slot"]);
          my ($gname, $gpasswd, $ggid, $gmembers) = getgrnam(@{$d_struct->{acct}->{group}}["$restore_slot"]);
          chown($uuid, $ggid, @{$d_struct->{acct}->{file}}["$restore_slot"]);
          $restore_slot++;
        }
      }
      if ( -d  @{$d_struct->{acct}->{file}}[0] && @{$d_struct->{acct}->{file}}[0] =~ /public_html/ ) {
        # Don't touch htaccess if owner or perm only options given.
        if ( ! $base_conf{ownerships_only} && ! $base_conf{perms_only} ) {
          $self->print_i({ msg => "Uncommenting php tweaks for $user.." });
          system("find @{$d_struct->{acct}->{file}}[0] -name .htaccess -exec sed -i 's/^#php_/php_/g' {} \\\;");
        }
      }
      else {
        $self->logger({ level => 'w', msg => "do_restore() base document root (@{$d_struct->{acct}->{file}}[0]) doesn't exist, or doesn't contain public_html.." });
      }
      $self->print_n({ msg => "suPHP fixes reverted for $cpUser! {Completed: $restored_accounts/$to_restore_total}" });
      $restored_accounts++;
    }
    $self->print_n({ msg => "suPHP fixes reverted for $to_restore_total accounts." });
  }
  else {
    ## 'restore-state' single user..
    $self->print_n({ msg => "Reverting suPHP fixes for $opts->{param}.." });
    unless ( $self->valid_user({ user => $opts->{param} }) ) {
      $self->print_c({ msg => "cPanel user '$opts->{param}' is no longer a valid user on this system!" });
    }
    my $json_file_path = $base_conf{'store_path'};
    $json_file_path .= "/datastore_suphpfix.";
    $json_file_path .= "$opts->{param}.json";
    unless ( -e $json_file_path ) {
      $self->print_c({ msg => "Datastore file ($json_file_path) for $opts->{param} no longer exists. Please take another snapshot or restore datastore files from a previous snapshot." });
    }
    if ( -z $json_file_path ) {
      $self->print_c({ msg => "Datastore file ($json_file_path) for $opts->{param} exists but is empty. Please take another snapshot or restore datastore files from a previous snapshot." });
    }
    open FILE, "<$json_file_path";
    my $json_text = do { local $/; <FILE> };
    close(FILE);
    my $d_struct;
    eval {
      $d_struct = $json->allow_nonref->utf8->relaxed->decode($json_text);
    };
    if ($@) {
      $self->print_c({ msg => "Datastore file ($json_file_path) is not valid JSON. Please take another snapshot or restore datastore files from a previous snapshot." });
    }
    $self->print_i({ msg => "Reverting file/dir permissions/ownerships for $opts->{param}.." });
    my $restore_slot = 0;
    for my $restore_user ( @{$d_struct->{acct}->{cpanelUser}} ) {
      unless ( -e @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
        $self->print_w({ msg => "@{$d_struct->{acct}->{file}}[\"$restore_slot\"] no longer exists, skipping.." });
        $restore_slot++;
        next;
      }

      if ( $base_conf{'clobber_hlinks'} ) {
        if ( ! -d @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
          my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = $self->get_stat({ name => @{$d_struct->{acct}->{file}}["$restore_slot"] });
          if ( $nlink > 1 ) {
            $self->print_w({ msg => "Clobbering hard link file @{$d_struct->{acct}->{file}}[\"$restore_slot\"] per user request!" });
          }
        }
      }
      else {
        if ( ! -d @{$d_struct->{acct}->{file}}["$restore_slot"] ) {
          my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = $self->get_stat({ name => @{$d_struct->{acct}->{file}}["$restore_slot"] });
          if ( $nlink > 1 ) {
            $self->print_i({ msg => "Skipping hard link file @{$d_struct->{acct}->{file}}[\"$restore_slot\"].." });
            $restore_slot++;
            next;
          }
        }
      }

      if ( $base_conf{ownerships_only} ) {
        my ($uname, $upass, $uuid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) = getpwnam(@{$d_struct->{acct}->{owner}}["$restore_slot"]);
        my ($gname, $gpasswd, $ggid, $gmembers) = getgrnam(@{$d_struct->{acct}->{group}}["$restore_slot"]);
        chown($uuid, $ggid, @{$d_struct->{acct}->{file}}["$restore_slot"]);
        $restore_slot++;
      }
      elsif ( $base_conf{perms_only} ) {
        chmod oct(@{$d_struct->{acct}->{perm}}["$restore_slot"]), @{$d_struct->{acct}->{file}}["$restore_slot"];
        $restore_slot++;
      }
      else {
        chmod oct(@{$d_struct->{acct}->{perm}}["$restore_slot"]), @{$d_struct->{acct}->{file}}["$restore_slot"];
        my ($uname, $upass, $uuid, $ugid, $uquota, $ucomment, $ugcos, $udir, $ushell, $uexpire) = getpwnam(@{$d_struct->{acct}->{owner}}["$restore_slot"]);
        my ($gname, $gpasswd, $ggid, $gmembers) = getgrnam(@{$d_struct->{acct}->{group}}["$restore_slot"]);
        chown($uuid, $ggid, @{$d_struct->{acct}->{file}}["$restore_slot"]);
        $restore_slot++;
      }
    }
    if ( -d  @{$d_struct->{acct}->{file}}[0] && @{$d_struct->{acct}->{file}}[0] =~ /public_html/ ) {
      # Don't touch htaccess if owner or perm only options given.
      if ( ! $base_conf{ownerships_only} && ! $base_conf{perms_only} ) {
        $self->print_i({ msg => "Uncommenting php tweaks for  $opts->{param}.." });
        system("find @{$d_struct->{acct}->{file}}[0] -name .htaccess -exec sed -i 's/^#php_/php_/g' {} \\\;");
      }
    }
    else {
      $self->logger({ level => 'w', msg => "do_restore() base document root (@{$d_struct->{acct}->{file}}[0]) doesn't exist, or doesn't contain public_html.." });
    }
    $self->print_n({ msg => "suPHP fixes  reverted for $opts->{param}!" });
    $self->print_n({ msg => "suPHP fixes reverted for 1 accounts." });
  }
}

1;
