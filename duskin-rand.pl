#!/usr/bin/perl -w

# Copyright (c) 2009, Yusuke Izumi <yizumi@ripplesystem.com>

# Permission to use, copy, modify, and/or distribute this software for any
# non-commercial purpose with or without fee is hereby granted, provided that
# the above copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# This script opens a TCP/IP port so that external clients can listen to
# XBee RxResponses, as well as send TxRequests to XBee devices though TCP/IP
# connection.

use warnings;
use strict;

# use Gtk2 -init;
# use Gnome2::Canvas;
use POE qw( Component::Server::TCP Filter::HTTPD);
use JSON;
use Date::Format qw( time2str );
use Xbee::API;
use threads;
use FindBin;
use LWP::UserAgent;
use HTTP::Request;
use POSIX;

use lib "$FindBin::Bin";
use XBDB;

my $HOME = "$FindBin::Bin";
my $HOME_DH;
opendir($HOME_DH, $HOME); 
chdir $HOME_DH or die "Coule not change directory";
my $LISTENING_PORT = 80;

#---------------------------------------------
sub logger
#---------------------------------------------
{
	my $message = join( " ", @_ );
	my( $package, $filename, $line ) = caller;
	if( $filename =~ m/.+\/([_\.A-Za-z]+)$/ ) {
		$filename = $1;
	}

	my $time = time2str( "%Y/%m/%d %H:%M:%S %z", time() );

	if( $_[0] eq "DEBUG" ) {
        return;
    }
	if( $_[0] eq "WARNING" || $_[0] eq "ERROR" ) {
		print STDERR "[$time] $message ($filename:$line)\n";
	} else {
		print STDOUT "[$time] $message ($filename:$line)\n";
	}
}

sub randomSender{
	logger( "INFO", "Initializing database" );
	my $xbdb = new XBDB( "localhost", "xbdb", "xbdb", "_xbdb" );

	logger( "INFO", "Getting Nodes data" );
	my @nodes = ();
	$xbdb->execQuery( "SELECT * FROM Node WHERE deviceId='PANDA:DEVICE:002'" )->each(sub{
		my( $row, $index, $key ) = @_;
		push( @nodes, $row );
	});
	

	my $remote = IO::Socket::INET->new(
		Proto => "tcp",
		PeerAddr => "localhost",
		PeerPort => $LISTENING_PORT
	) or die( "FATAL: Failed to establish TCP/IP Connection at port $LISTENING_PORT" );

	logger( "INFO", "Connected to port $LISTENING_PORT" );
	logger( "INFO", "Setting connection type to PUBLISHER" );
	print $remote "GET /publish HTTP/1.1\r\n\r\n";

	my $http_request = HTTP::Request->new("POST", "/publish");

	while (1) {
		my $nodeIndex = floor( rand() * scalar( @nodes ) );
		my $node = $nodes[$nodeIndex];
		my $serial = $node->{"serial"};
		my $frame = {
			"options" => 0,
			"nodeInfo" => $node,
			"raw_data" => "82${serial}28000101000000",
			"serial" => $serial,
			"data" => "\u0001\u0001\u0000\u0000\u0000",
			"rssi" => 40,
			"checksum" => "OK",
			"serverRecpTime" => time2str( "%Y-%m-%dT%H:%M:%SZ%z", time() ),
			"length" => 16,
			"type" => "SampleReading"
		};
		$xbdb->storeRxFrame( $frame );
        # logger( "INFO", "0x" . unpack( "H*", $frame->{raw_data} ) );
		$frame->{type} = "SampleReading";
		my $msg = to_json( $frame ) . "\r\n";
		print( $msg );

		$http_request->content( $msg );
		$http_request->header( "Content-Length" => length( $msg ) );
		print $remote $http_request->as_string;

		my $timeToWait = floor( (rand()) * 5 + 1 );
		logger( "INFO", "Waiting for $timeToWait secs..." );
		sleep( $timeToWait );
	}
}

randomSender();

exit 0;
