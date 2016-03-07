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
use parent 'suPHPfix::API';

use File::stat;
use Fcntl ':mode';
use File::Find ();
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;


#-------------------------------------------------------------------------------
# Methods
#-------------------------------------------------------------------------------

sub do_prep {
  my $self = shift;
  my $opts = shift;
  my $accntList = $self->call({ url => "http://127.0.0.1:2086/json-api/listaccts" });
  my $accnts_cnt = 0;
  for my $acct ( @{$accntList->{acct}} ) {
    $accnts_cnt++;
  };
  my %error_states = ( prep => {}, );
  if ( $opts->{param} eq 'all' ) {
    ## 'Prep' all, 1 cPanel account.
    my $count = 0;
    if ( $accnts_cnt == 1 ) {
      $self->print_n({ msg => "Discovered one account." });
      my ($domain, $docroot_details, $user);
      for my $users( @{$accntList->{acct}} ) {
        $user = $users->{user};
        $domain = $users->{domain};
        $docroot_details =
        $self->call({ url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
      };
      $self->print_n({ msg => "Preparing $user..." });
      my $docroot = $docroot_details->{userdata}->{documentroot};
      my $home_dir = $docroot_details->{userdata}->{homedir};
      my ($cmd_error,$msg) = $self->runCmds({ user => "$user", domain => "$domain", docroot => "$docroot", home_dir => "$home_dir" });
      if ( $cmd_error ) {
        $error_states{'prep'}{"$user"}{'msg'} = "$msg";
      }
      $count++;
      if ( $error_states{'prep'}{"$opts->{param}"}{'msg'} ) {
        my $err_msg = $error_states{'prep'}{"$opts->{param}"}{'msg'};
        $self->print_w({ msg => "Error(s) encountered while doing prep for $opts->{param}! Details below:\n$err_msg" });
      }
      else {
        $self->print_n({ msg => "Completed: $count / $accnts_cnt" });
      }
    }
    else {
      ## 'Prep' all, more than 1 cpanel user.
      $self->print_n({ msg => "Discovered multiple accounts." });
      my ($domain,$user,$docroot,$home_dir);  
      my $count = 0;
      for my $userCnt( @{$accntList->{acct}} ) {
        $user = $userCnt->{user};
        $self->print_n({ msg => "Preparing $user..." });
        $domain = $userCnt->{domain};
        my $docroot_details =
        $self->call({ url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
        $docroot = $docroot_details->{userdata}->{documentroot};
        $home_dir = $docroot_details->{userdata}->{homedir};
        my ($cmd_error,$msg) = $self->runCmds({ user => "$user", domain => "$domain", docroot => "$docroot", home_dir => "$home_dir" });
        if ( $cmd_error ) {
          $error_states{'prep'}{"$user"}{'msg'} = "$msg";
        }
        $count++;
        if ( $error_states{'prep'}{"$opts->{param}"}{'msg'} ) {
          my $err_msg = $error_states{'prep'}{"$opts->{param}"}{'msg'};
          $self->print_w({ msg => "Error(s) encountered while doing prep for $user! Details below:\n$err_msg" });
        }
        else {
          $self->print_n({ msg => "Completed: $count / $accnts_cnt" });
        }
      };
    }  
  }
  else {
    ## Single user --prep
    $self->print_n({ msg => "Preparing $opts->{param}..." });
    my ($docroot, $domain, $home_dir);
    for my $userCnt( @{$accntList->{acct}} ) {
      if ( $userCnt->{user} eq $opts->{param} ) {
        $domain = $userCnt->{domain};
        my $domain_details =
        $self->call({ url => "http://127.0.0.1:2086/json-api/domainuserdata?domain=$domain" });
        $docroot = $domain_details->{userdata}->{documentroot};
        $home_dir = $domain_details->{userdata}->{homedir};
        my ($cmd_error,$msg) = $self->runCmds({ user => "$opts->{param}", domain => "$domain", docroot => "$docroot", home_dir => "$home_dir" });
        if ( $cmd_error ) {
          $error_states{'prep'}{"$opts->{param}"}{'msg'} = "$msg";
        }
        if ( $error_states{'prep'}{"$opts->{param}"}{'msg'} ) {
          my $err_msg = $error_states{'prep'}{"$opts->{param}"}{'msg'};
          $self->print_w({ msg => "Error(s) encountered while doing prep for $opts->{param}! Details below:\n$err_msg" });
        }
        else {
          $self->print_n({ msg => "Finished preping $opts->{param}!" });
        }
      }
    };
  }
  $self->cleanup();
  $self->checkLogSize();
}

sub runCmds {
  my $self = shift;
  my $opts = shift;

  $self->print_i({ msg => "Discovered document root: $opts->{docroot}" });
  my $base_conf_ref = $self->get_baseconf();
  my %base_conf = %$base_conf_ref;

  # Initial sanity checks
  #######################################

  unless ( -d $opts->{docroot} ) {
    return(1,"Discovered document root ($opts->{docroot}) doesn't exist!")
  }
  if ( $opts->{docroot} !~ m/^\/home/ ) {
    return(1,"Discovered document root ($opts->{docroot}) for $opts->{user} doesn't start with /home*!");
  }  
  if ( $opts->{home_dir} !~ m/^\/home/ ) {
    return(1,"Discovered home dir ($opts->{home_dir}) for $opts->{user} doesn't start with /home*!");
  }

  #
  # Populate file & dir entries
  #######################################

  my $dirs = $self->get_recursive_dirs({ dir => $opts->{docroot} });
  my $files;
  if ( $base_conf{'clobber_hlinks'} ) {
    $files = $self->get_recursive_files({ dir => $opts->{docroot}, no_hlinks => 0 });
  }
  else {
    $files = $self->get_recursive_files({ dir => $opts->{docroot}, no_hlinks => 1 });
  }

  #
  # Get system user info
  #######################################
  
  my ($login,$pass,$uid,$gid) = getpwnam($opts->{user}) or return(1,"Can't find $opts->{user} in /etc/passwd; Can't get numeric uids!");
  my ($nobody_login,$nobody_pass,$nobody_uid,$nobody_gid) = getpwnam('nobody') or return(1,"Can't find nobody in /etc/passwd; Can't get numeric uids!");

  #
  # Directory Permissions & Ownerships
  #######################################
  
  if ( $base_conf{ownerships_only} ) {
    $self->print_i({ msg => "Checking directory ownerships..." });
    for my $dir ( @{ $dirs } ) {
      chown($uid, $gid, $dir);
    }
    chown($uid, $gid, $opts->{home_dir});
    # public_html should be user:nobody
    chown($uid, $nobody_gid, $opts->{docroot});
  }
  elsif ( $base_conf{perms_only} ) {
    $self->print_i({ msg => "Checking directory permissions..." });
    for my $dir ( @{ $dirs } ) {
      chmod oct('0755'), $dir;
    }
    chmod oct('0750'), $opts->{docroot};
    chmod oct('0711'), $opts->{home_dir};
  }
  else {
    $self->print_i({ msg => "Checking directory permissions and ownerships..." });
    for my $dir ( @{ $dirs } ) {
      chmod oct('0755'), $dir;
      chown($uid, $gid, $dir);  
    }
    chmod oct('0750'), $opts->{docroot};
    chmod oct('0711'), $opts->{home_dir};
    chown($uid, $gid, $opts->{home_dir});
    # public_html should be user:nobody
    chown($uid, $nobody_gid, $opts->{docroot});
  }

  #
  # File Permissions & Ownerships
  #######################################
  
  if ( $base_conf{ownerships_only} ) {
    $self->print_i({ msg => "Checking file ownerships..." });
    for my $file ( @{ $files } ) {
      chown($uid, $gid, $file);
    }
  }

  elsif ( $base_conf{perms_only} ) {
    $self->print_i({ msg => "Checking file permissions..." });
    for my $file ( @{ $files } ) {
      # Perform chmod tasks on file.
      $self->do_prep_perms_on_file({ file => $file });
    }
  }
  else {
    $self->print_i({ msg => "Checking file permissions and ownerships..." });
    for my $file ( @{ $files } ) {
      # Perform chmod tasks on file.
      $self->do_prep_perms_on_file({ file => $file });
      chown($uid, $gid, $file);
    }
  }

  #
  # Incompatible .htaccess entries
  #######################################

  # Don't touch htaccess if owner or perm only options given.
  if ( ! $base_conf{ownerships_only} && ! $base_conf{perms_only} ) {
    # If no htscanner, comment out php tweaks from .htaccess files.
    unless ( $self->htscanner() ) {
      $self->print_i({ msg => "Commenting out php tweaks from .htaccess files.." });
      system("find $opts->{docroot} -name .htaccess -exec sed -i 's/^php_/#php_/g' {} \\\;");
    }
  }

}

sub do_prep_perms_on_file {
  my $self = shift;
  my $opts = shift;

  my $world_writable = 0;
  my $group_writable = 0;

  my $file_info = stat($opts->{file});
  my $retMode = $file_info->mode;
  $retMode = $retMode & 0777;

  $group_writable = 1 if ( $retMode & S_IWGRP );
  $world_writable = 1 if ( $retMode & S_IWOTH );

  # Remove group or world write... 
  if ( $world_writable || $group_writable ) {

    # Get octal form of files permissions.
    my $file_permissions_oct = sprintf "%04o", S_IMODE($retMode);

    # Get all but last two (group and world) permission bits.
    my $permissions_all_but_last_two_oct = substr($file_permissions_oct, 0, -2);

    # Get last two permission bits (group and world).
    my $file_permissions_oct_group_world_oct = substr($file_permissions_oct, -2);

    my @bits = split("", $file_permissions_oct_group_world_oct);

    # remove writable bit '2' from group if its writable.
    if ( $group_writable ) {
      if ( $bits[0] && $bits[0] >= 2 ) {
        $bits[0] = $bits[0] - 2;
      }
    }
  
    # remove writable bit '2' from world if its writable.
    if ( $world_writable ) {
      if ( $bits[1] && $bits[1] >= 2 ) {
        $bits[1] = $bits[1] - 2;
      }
    }

    # Start formulating new octal permission.
    my $new_octal_perm = $permissions_all_but_last_two_oct;

    if ( defined($bits[0]) && defined($bits[1]) ) {
      $new_octal_perm .= $bits[0];
      $new_octal_perm .= $bits[1];
    }
    else {
      $self->logger({ 
          level => 'c', 
          msg => "Failed to get last two octal bits of [$opts->{file}]" 
        });
    }
    chmod oct($new_octal_perm), $opts->{file};
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
  $self->print_i({ msg => "Cleaning up..." });
  chmod oct('1777'), '/tmp';
  chmod oct('0700'), '/tmp/screens/S-root';
  chmod oct('0755'), '/tmp/screens';
}

sub checkLogSize {
  my $self = shift;
  my $opts = shift;

  $self->print_i({ msg => "Checking size of logs..." });
  my $twoGBInBytes = '2147483648';
  my @log_files = ( '/usr/local/apache/logs/suphp_log', '/usr/local/apache/logs/error_log', '/usr/local/apache/logs/suexec_log', '/usr/local/apache/logs/access_log' );
  for my $logFile ( @log_files ) {
    if ( ! -e $logFile ) {
      $self->print_w({ msg => "$logFile doesn't exist." });
      next;
    }
    my $fileSize = -s $logFile;
    if ( $fileSize >= $twoGBInBytes ) {
      $self->print_w({ msg => "Log file ($logFile) is >= 2GB. This logfile should be cleared or rotated to avoid problems with the webserver. If logrotate is not configured, do the needful." });
    }
  }
}


1;
