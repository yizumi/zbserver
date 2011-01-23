#!/usr/bin/perl

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
use IO::Socket::INET;
use JSON;
use Date::Format qw( time2str );
use Xbee::API;
use threads;
use FindBin;
use LWP::UserAgent;
use HTTP::Request;
use Digest::MD5 qw( md5 );
use Data::Dumper;

use lib "$FindBin::Bin";
use XBDB;

$| = 1;			 # Flush Output

# Publisher Settings
my $PUBLISHER_HOST = "zb1.ripplesystem.com";
my $PUBLISHER_PORT = 8080;

my %LOGLEVEL = ( 
    "DEBUG"     => 0, 
    "INFO"      => 1, 
    "WARNING"   => 2, 
    "ERROR"     => 3, 
    "FATAL"     => 4
);

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

#---------------------------------------------
sub trim
#---------------------------------------------
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
    $string =~ s/\x00//;
	return $string;
}

my $cnx;
my $lastDelay = 1;

sub getConnection
{
	while( !(defined $cnx && $cnx->connected) )
	{
		logger( "INFO", "Connecting to $PUBLISHER_HOST:$PUBLISHER_PORT" );

		eval {
			$cnx = IO::Socket::INET->new(
				Proto => "tcp",
				PeerAddr => $PUBLISHER_HOST,
				PeerPort => $PUBLISHER_PORT
			) or die("Failed to conenct to $PUBLISHER_HOST:$PUBLISHER_PORT" );
		};

		if( $@ )
		{
			logger( "INFO", "Reconnecting in $lastDelay seconds" );
			sleep( $lastDelay );
			$lastDelay = $lastDelay < 32 ? $lastDelay *= 2 : $lastDelay;
		}
		else
		{
			logger( "INFO", "Connected to $PUBLISHER_HOST:$PUBLISHER_PORT" ) if (defined $cnx && $cnx->connected);
			logger( "INFO", "Setting connection type to PUBLISHER" );
			print $cnx "GET /publish HTTP/1.1\r\n\r\n";
			$lastDelay = 1;
		}
	}
	return $cnx;
}

my %cached_node_data = {};

#---------------------------------------------
sub enrichNodeData
#---------------------------------------------
{
    my( $frame, $xbdb ) = @_;
	if( !exists( $cached_node_data{$frame->{serial}} ) )
	{
	    my $rs = $xbdb->execQuery( "SELECT * FROM Node WHERE serial=?", $frame->{serial} );
	    $rs->each( sub {
		    $cached_node_data{$frame->{serial}} = shift;
	    });
	}
	$frame->{nodeInfo} = $cached_node_data{$frame->{serial}};
	$frame->{serverRecpTime} = time2str( "%Y-%m-%dT%H:%M:%SZ%z", time() );
}

#---------------------------------------------
sub sendHttpRequest
#---------------------------------------------
{
	my( $http_request ) = @_;
	my $cnx = getConnection();
	print $cnx $http_request->as_string;
	logger( "INFO", "Sent: " . $http_request->as_string );
}

# We want to buffer the data until we see end of line
my %buffered_data = {};
sub buffer_rs232_input
{
	my( $serial, $partial_data ) = @_;
	my $line;
	my $byte;

	foreach $byte ( split //, $partial_data ) {
		if( $byte =~ /\x02/ ) {
			$buffered_data{$serial} = "";
		}
		elsif( $byte =~ /\x03/ ) {
			$line = $buffered_data{$serial};
		}
		else {
			$buffered_data{$serial} .= $byte;
		}
	}
	return $line;
}

sub main
{
	# Create
	logger( "INFO", "Opening Xbee device" );
	my $xbee = Xbee::API->new( { port => '/dev/ttyUSB0', debug => 0, speed => 9600 } );

	logger( "INFO", "Initializing database" );
	my $xbdb = new XBDB( "localhost", "xbdb", "xbdb", "_xbdb" );

	logger( "INFO", "Sending Node Discovery Command to get replies from end-nodes" );
	$xbee->at_command("ND");
	# $xbee->transmit_request( "\x0013A200406292D4", "L0H" );

	my $http_request = HTTP::Request->new("POST", "/publish");
	my $frame;
	my $lastError = 0;

	while (1) {

		
		eval {
			$frame = $xbee->read_api;
		};

		if( $@ ) {
			if( $lastError == 0 ) {
				$lastError = 1;
				logger( "Cannot Xbee device disconnected: $@" );
			}
			next;
		}
		else {
			$lastError = 0;
		}

		# print Dumper( $frame );
		if( exists $frame->{type} ) {
			# enrich the frame with data
			enrichNodeData( $frame, $xbdb );

			# Hold on!  Pool the data before it goes out if it's a frame from RS232 adapter.
			if( $frame->{nodeInfo}->{deviceId} eq "XBEE:ADAPTER:RS232" )
			{
				my $complete_data = buffer_rs232_input( $frame->{serial}, $frame->{data} );
				next if( !$complete_data );
				next if( $complete_data eq "300081F000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" );
				# continue processing if we've received a full legth-data.
				$frame->{data} = $complete_data;
			}

			if( $frame->{type} == 0x80 ) {
				$xbdb->storeRxFrame( $frame );
				
				# Now ... let subscribers be aware of this change!
				$frame->{type} = "RxResponse";
				my $msg = to_json( $frame ) . "\r\n";
				$http_request->content( $msg );
				$http_request->header( "Content-Length" => length( $msg ) );
				sendHttpRequest( $http_request );
				# delete $frame->{raw_data};

				if( $frame->{data} =~ /CS[HL]+/ ) {
					$xbdb->setCurrentState( $frame->{serial}, $frame->{data} );
				}
			}
			elsif( $frame->{type} == 0x88 ) {
				if( $frame->{at_command} eq "ND" ) {
					if( $frame->{at_data} ne "" ) {
						my @chunk = split('',$frame->{at_data});
						my $my = unpack( "H*", Xbee::API::_shift( \@chunk, 2 ) );
						my $serial = unpack( "H*", Xbee::API::_shift( \@chunk, 8 ) );
						my $db = unpack( "C", shift @chunk );
						my $identifier = trim( join( '', @chunk ) );
						logger( "INFO", "Found device $identifier" );
						$xbdb->setNode( $serial, $my, $db, $identifier );
					}
				}
			}
			elsif( $frame->{type} == 0x82 ) {
				$xbdb->storeRxFrame( $frame );
				# logger( "INFO", "0x" . unpack( "H*", $frame->{raw_data} ) );
				$frame->{type} = "SampleReading";
				
				my $msg = to_json( $frame ) . "\r\n";
				$http_request->content( $msg );
				$http_request->header( "Content-Length" => length( $msg ) );
				sendHttpRequest( $http_request );
			}
			else {
				logger( "INFO", "0x" . unpack( "H*", $frame->{raw_data} ) );
				$frame->{type} = "Unknown";
				my $msg = to_json( $frame ) . "\r\n";
				$http_request->content( $msg );
				$http_request->header( "Content-Length" => length( $msg ) );
				sendHttpRequest( $http_request );
			}
		}
	}

	return 0;
}

exit main();
