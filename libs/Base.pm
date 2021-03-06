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

package suPHPfix::Base;
use Term::ANSIColor;
use File::Path qw(mkpath);
use File::Find;


#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

my %base_conf = (
  version => '3.0.9',
  warn_sleep_seconds => '10',
  lock_file => '/var/lock/suphpfix.lock',
  log_path => '/var/log',
  all_user_list => '/var/cache/suphpfix/backedupUserList.all',
  log_file => '/var/log/suphpfix.log',
  store_path => '/var/cache/suphpfix',
  author => 'scottgregorysullivan@gmail.com',
  helpers => 'N/A',
);

#-------------------------------------------------------------------------------
# Constructor
#-------------------------------------------------------------------------------

sub new {
  return bless {}, shift;
}

#-------------------------------------------------------------------------------
# Methods
#-------------------------------------------------------------------------------

sub help {
  my $self = shift;
  my $help_msg = "\nsuPHPfix help --- version: $base_conf{'version'}

USAGE: $0 [--prep (all||cPanelUser) [OPTIONAL_ARGS]|--save-state (all||cPanelUser) [OPTIONAL_ARGS]|--restore-state (all||cPanelUser) [OPTIONAL_ARGS]]

--prep  -->
  Accepts either 'all' to prep all cPanel users on the system for suPHP, or the individual cPanel
  user, to prep just that one user.

--save-state  -->
        Accepts either 'all' to save all cPanel users on the system permissions/ownership settings, or 
  saves the permission/ownership settings for just the cPanel user specified. By default, this 
  information will be stored in JSON files in $base_conf{'store_path'}. 

--restore-state  -->
  Accepts either 'all' to restore all cPanel users on the system (that were backed up with --save-state)
  or just the cPanel user specified. By default, this will look for the JSON files in 
  $base_conf{'store_path'}.

-v  -->
  Show suPHPfix version. 

--help -->
  Show this help message.

OPTIONAL ARGUMENTS:
  --clobber-hard-links -->
    You are requesting to change permissions and ownerships of hardlink files. This is a potential security risk.
    For this option to do anything, you must also pass '--yes-i-mean-it'.

  --yes-i-mean-it -->
    You want to perform the operation regardless of the warnings.

  --ownerships-only -->
    You want to perform only the ownership changes. This option cannot be combined with --perms-only.

  --perms-only -->
    You want perform only the permission changes. This option cannot be combined with --ownerships-only.
  
";
  print $help_msg , "\n";
  $self->do_exit();
}

sub show_version {
  print "suPHPfix version: $base_conf{'version'}\n";
}

sub do_startup {
  my $self = shift;
  $self->logger({ level => 'n', msg => "Initiated Startup" });
  $self->show_gpl();
  $self->ensure_root();
  $self->can_run();
  $self->fs_path_ensure();
  $self->place_lock();
  $self->ensure_modules();
}

sub show_gpl {
  print "\nsuphpfix  Copyright (C) 2009-2014  Scott Sullivan ($base_conf{'author'})
This program comes with ABSOLUTELY NO WARRANTY; for details refer to the GPLv3 
license, in the source of this application. This is free software, and you are 
welcome to redistribute it under certain conditions; refer to the GPLv3 for
details.\n\n";
}

sub hlink_warning {
  my $self = shift;
  my $opts = shift;

  my $warn_msg = "Using option '--clobber-hard-links' is a potential security risk.";
  if ( $opts->{yes_i_mean_it} ) {
    $self->print_w({ msg => "$warn_msg Proceeding anyways in $base_conf{'warn_sleep_seconds'} seconds per option '--yes-i-mean-it'...\n" });
    $base_conf{'clobber_hlinks'} = 1;
    sleep $base_conf{'warn_sleep_seconds'};
  }
  else {
    $self->print_w({ msg => "$warn_msg If you understand the risk and wish to proceed anyways, please add option '--yes-i-mean-it'.\n"});
    $self->do_exit();
  }
}

sub lock_stale {
  my $self = shift;
  open FH, "<", "$base_conf{lock_file}" || $self->logger({ level => 'c', msg => "Unable to open $base_conf{lock_file}!" });
  my $pid = <FH>;
  close(FH);
  
  if ( $pid && kill(0 => $pid) ) {
    # Not stale
    return 0;
  }
  else {
    # Stale
    return 1;
  }
}

sub can_run {
  my $self = shift;
  if ( -e $base_conf{'lock_file'} ) {
    if ( $self->lock_stale() ) {
      $self->print_w({ msg => "Lock file exists, but contains stale PID, removing lock and continuing." });
      unlink($base_conf{lock_file});
    }
    else {
      $self->logger({ level => 'c', msg => "Refusing to run, non stale lock file ($base_conf{'lock_file'}) present." });
    }
  }
}

sub ensure_root {
  my $self = shift;
  if ( $< != 0 ) {
    print STDERR "suPHPfix requires root level privileges.\n";
    $self->do_exit();
  }
}

sub ensure_modules {
  my $self = shift;

  ## LWP::UserAgent
  my $timed_out = 0;
  unless ( eval { require LWP::UserAgent; 1; } ) {
    $self->logger({ level => 'w', msg => "Required perl module (LWP::UserAgent) is missing. Attempting install..." });
    eval {
      local $SIG{ALRM} = sub { die "alarm\n" };
      alarm 240; 
      $self->cpan_install({ module => 'LWP::UserAgent' });
      alarm 0;
    };
    if ( $@ ) {
      $timed_out = 1;
    }
    if ( $timed_out == 1 ) {
      $self->logger({ level => 'c', msg => "Timed out trying to install required LWP::UserAgent module!" });
    }
  }
  unless ( eval { require LWP::UserAgent; 1; } ) {
    $self->logger({ level => 'c', msg => "Failed to install module LWP::UserAgent!" });
  }

  ## JSON
  $timed_out = 0;
  unless ( eval { require JSON; 1; } ) {
    $self->logger({ level => 'w', msg => "Required perl module (JSON) is missing. Attempting install..." });
    eval {
      local $SIG{ALRM} = sub { die "alarm\n" };
      alarm 240;
      $self->cpan_install({ module => 'JSON' });
      alarm 0;
    };
    if ( $@ ) {
      $timed_out = 1;
    }
    if ( $timed_out == 1 ) {
      $self->logger({ level => 'c', msg => "Timed out trying to install required JSON module!" });
    }
  }
  unless ( eval { require JSON; 1; } ) {
    $self->logger({ level => 'c', msg => "Failed to install module JSON!" });
  }
}

sub cpan_install {
  my $self = shift;
  my $opts = shift;
  $self->logger({ level => 'c', msg => "cpan_install called with no module given!" }) unless $opts->{module};
  my $stderr = `yes | cpan -i "$opts->{module}" 2>&1 1>/dev/null`;
  if ( $? != 0 ) {
    chomp($stderr);
    $self->logger({ level => 'c', msg => "Attempt to automatically install $opts->{module} failed; got: $stderr" });
  }
}

sub fs_path_ensure {
  unless ( -d $base_conf{'log_path'} ) {
    mkpath($base_conf{log_path});
  }
  unless ( -e $base_conf{'log_file'} ) {
    open(FH,">$base_conf{'log_file'}") or die "Unable to create log file $base_conf{'log_file'}; Got: $!";
    close(FH);
  }
  unless ( -d $base_conf{'store_path'} ) {
    mkpath($base_conf{store_path});
  }
}

sub do_exit {
  my $self = shift;
  my $opts = shift;
  if ( $opts->{type} ) {
    if ( $opts->{type} eq 'noclean' ) {
      exit 1;
    }
  }
  unlink($base_conf{'lock_file'});
  $self->logger({ level => 'n', msg => "Initiated Shutdown" });
  exit 1;
}

sub place_lock {
  my $self = shift;
  open(my $fh, '>', $base_conf{'lock_file'}) || $self->logger({ level => 'c', msg => "Unable to create lock file! Got: $!" });
  print $fh $$;
  close(FH);
}

sub rm_lock {
  if ( -e $base_conf{'lock_file'} ) {
    unlink("$base_conf{'lock_file'}");
  }
}

sub get_time {
  my $self = shift;
  use Time::localtime;
  my $cur_time = ctime();
  return $cur_time;
}

sub print_w {
  my $self = shift;
  my $opts = shift;
  $self->logger({ level => 'c', msg => "print_w() called with no msg given!" }) unless $opts->{msg};
  print color 'reset';
  print color 'yellow';
  print "[ ", $self->get_time(), " ] WARNING: $opts->{msg}\n";
  $self->logger({ level => 'w', msg => "$opts->{msg}" });
  print color 'reset';
}

sub print_n {
  my $self = shift;
  my $opts = shift;
  $self->logger({ level => 'c', msg => "print_n() called with no msg given!" }) unless $opts->{msg};
  print color 'reset';
  print color 'green';
  print "[ ", $self->get_time(), " ] NOTICE: $opts->{msg}\n";
  $self->logger({ level => 'n', msg => "$opts->{msg}" });
  print color 'reset';
}

sub get_baseconf {
  return \%base_conf;
}

sub print_i {
  my $self = shift;
  my $opts = shift;
  $self->logger({ level => 'c', msg => "print_i() called with no msg given!" }) unless $opts->{msg};
  print "[ ", $self->get_time(), " ] INFO: $opts->{msg}\n";
  $self->logger({ level => 'i', msg => "$opts->{msg}" });
}

sub print_c {
  my $self = shift;
  my $opts = shift;
  $self->logger({ level => 'c', msg => "print_c() called with no msg given!" }) unless $opts->{msg};
  print color 'reset';
  print color 'red';
  print "[ ", $self->get_time(), " ] CRIT: $opts->{msg}\n";
  $self->logger({ level => 'c', msg => "$opts->{msg}" });
  print color 'reset';
} 

sub logger {
  my $self = shift;
  my $opts = shift;
  my $cat_type;
  unless ( $opts->{msg} || $opts->{level} ) {
    die "logger called but missing level or msg!"
  }
  if ( $opts->{level} eq 'i' ) {
    $cat_type = 'INFO:';
  }
  elsif ( $opts->{level} eq 'c' ) {
    $cat_type = 'CRIT:';
  }
  elsif ( $opts->{level} eq 'w' ) {
    $cat_type = 'WARN:';
  }
  elsif ( $opts->{level} eq 'n' ) {
    $cat_type = 'NOTICE:';
  }
  else {
    die "Bad category passed to logger! ($opts->{level})\n";
  }
  if ( ! -e $base_conf{'log_file'} ) {
    open(FH,">$base_conf{'log_file'}") or die "Unable to create log file! Got: $!";
    close(FH);
  }
  if ( -w $base_conf{'log_file'} ) {
    open (LOG, ">>" , $base_conf{'log_file'}) or die "Can't open $base_conf{'log_file'} for writing: $!";
    print LOG "[ " , $self->get_time , " ] $cat_type $opts->{msg}\n";
    close (LOG);
    if ( "$opts->{level}" eq 'c' ) {
      print STDERR "\nFATAL: suPHPfix has encountered one or more fatal errors. Be sure to review the log ($base_conf{'log_file'}).

If you need help, consult one of the helpers ($base_conf{'helpers'}) or the author ($base_conf{'author'}).\n";
      if ( $opts->{msg} =~ /Refusing to run/ ) {
        $self->do_exit({ type => 'noclean' });
      }
      else {
        $self->do_exit();
      }
    }
  }
  else {
    print "$cat_type $opts->{msg}\n";
  }
}

sub get_recursive_dirs {
  my $self = shift;
  my $opts = shift;

  my @dirs = ();
  my $recursive_find_dir = sub {
    push(@dirs, $_) if ( -d $_ && ! -l $_ );
  };

  find({ wanted => \&$recursive_find_dir, no_chdir => 1 }, $opts->{dir});
  
  return \@dirs;
}

sub get_recursive_files {
  my $self = shift;
  my $opts = shift;

  my @files = ();

  # Find all files to chown/chmod, including hard links..
  if ( $base_conf{'clobber_hlinks'} ) {
    $self->logger({ level => 'w', msg => "Hard links will be included per user request!" });
    my $recursive_find_file = sub {
      if ( -f $_ && ! -l $_ ) {
        push(@files, $_);
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = $self->get_stat({ name => $_ });
        $self->print_w({ msg => "Hardlinked file [$_] marked for modification!" }) if ( $nlink > 1 );
      }
    };

    find({ wanted => \&$recursive_find_file, no_chdir => 1 }, $opts->{dir});
  }
  # Find all files to chown/chmod, excluding hard links..
  else {
    my $recursive_find_file = sub {
      my $file_name = $_;
      if ( -f $file_name && ! -l $file_name ) {
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = $self->get_stat({ name => $file_name });
        if ( $nlink <= 1 ) {
          push(@files, $file_name);
        }
        else {
          $self->print_n({ msg => "Skipping hardlinked file [$file_name]" });
        }
      }
    };

    find({ wanted => \&$recursive_find_file, no_chdir => 1 }, $opts->{dir});
  }

  return \@files;
}

sub get_stat {
  my $self = shift;
  my $opts = shift;

  return my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($opts->{name});
}

sub set_owner_or_perm_only {
  my $self = shift;
  my $opts = shift;

  if ( $opts->{ownerships_only} && $opts->{perms_only} ) {
    $self->logger({ level => 'c', msg => "Conflicting options given ownerships-only & perms-only" });
  }

  if ( $opts->{ownerships_only} ) {
    $base_conf{'ownerships_only'} = 1;
  }
  elsif ( $opts->{perms_only} ) {
    $base_conf{'perms_only'} = 1;
  }

}


1;
