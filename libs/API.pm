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

package suPHPfix::API;

require LWP::UserAgent;
use Encode;

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

sub valid_user {
	my $self = shift;
	my $opts = shift;
	die "Objects not passed to valid_user!" unless $opts->{objects};
	$opts->{objects}->{base}->logger({ level => 'c', msg => 'user was not passed to valid_user, cannot continue!' }) unless $opts->{user};
	my $accntList = $self->call({ objects => $opts->{objects}, url => "http://127.0.0.1:2086/json-api/listaccts" });
	for my $userCnt( @{$accntList->{acct}} ) {
		if ( $userCnt->{user} eq $opts->{user} ) {
			return 1;
		}
	};
	return 0;
}

sub call {
	my $self = shift;
	my $opts = shift;
	die "Objects not passed to call!" unless $opts->{objects};
	$opts->{objects}->{base}->logger({ level => 'c', msg => 'call called with no API url!' }) unless $opts->{url};
	my $params = $opts->{params} || {};
	my $auth = $self->getAuth({ objects => $opts->{objects} });
	require JSON;
	my $json = new JSON;
	my $ua = LWP::UserAgent->new;
	$ua->agent("suPHPfix");
	$ua->env_proxy();
	my $request = HTTP::Request->new(POST => $opts->{url});
	$request->header( Authorization => $auth );
	$request->content_type('application/jsonrequest');
	$request->content("$params");
	my $response = $ua->request($request);
	my $rawResponse = $response->content;
	my $result = encode("UTF-8", $rawResponse);
	my $decoded;
	eval {
		$decoded = $json->allow_nonref->utf8->relaxed->decode($result);
	};
	if ($@) {
		$opts->{objects}->{base}->logger({ level => 'c', msg => "Didn't receive a valid JSON response from cPanel API." });
	}
	return $decoded;
}

sub getAuth {
	my $self = shift;
	my $opts = shift;
	die "getAuth called without objects!" unless $opts->{objects};
	system("QUERY_STRING=\\\"regen=1\\\" /usr/local/cpanel/whostmgr/bin/whostmgr ./setrhash &> /dev/null");
	unless ( -e '/root/.accesshash' ) {
		$opts->{objects}->{base}->logger({ level => 'c', msg => "Failed to automatically generate hash! Please try logging into WHM and click `Setup Remote Access Key` and then re-run this script." });
	}
	open FILE, "</root/.accesshash";
	my $hash = do { local $/; <FILE> };
	close(FILE);
	$hash =~ s/\n//g;
	my $auth = "WHM root:" . $hash;
	return $auth;
}


1;
