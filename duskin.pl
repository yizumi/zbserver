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
use POE qw( Component::Server::TCP Filter::HTTPD);
use JSON;
use Date::Format qw( time2str );
use Xbee::API;
use threads;
use FindBin;

my $HOME = "$FindBin::Bin";
my $HOME_DH;
opendir($HOME_DH, $HOME); 
chdir $HOME_DH or die "Coule not change directory";

my $MIME = {
	"ico"   => "image/x-icon",
	"html"  => "text/html",
	"txt"   => "text/plain",
	"png"   => "image/png",
	"jpeg"  => "image/jpeg",
	"jpg"   => "image/jpg",
	"gif"   => "image/gif",
	"css"   => "text/css",
	"js"    => "application/x-javascript",
	"manifest" => "text/cache-manifest"
};

sub initDisplay
{
    Gtk2::Rc->add_default_file( "/usr/local/share/themes/Clearlooks-DarkOrange/gtk-2.0/gtkrc" );
    my %screen_size = ( "w" => 480, "h" => 272);

    my $bgColor = Gtk2::Gdk::Color->new (0xFFFF,0xFFFF,0xFFFF);

    my $window = Gtk2::Window->new("toplevel");
    $window->modify_bg( "normal", $bgColor );


    my $fixed = Gtk2::Fixed->new();
    $window->add( $fixed );
    $fixed->modify_bg( "normal", $bgColor );

    # my $button = Gtk2::Button->new("Quit");
    # $button->signal_connect( clicked => sub { Gtk2->main_quit } );
    # $fixed->put( $button, 180, 120 );

    my $image = Gtk2::Image->new_from_file( "/home/yizumi/bin/res/duskin256.png" );
    $window->set_default_size( $screen_size{"w"}, $screen_size{"h"} );
    $fixed->put( $image, ($screen_size{"w"}/2) - (280/2), 80 );

    my $progressBar = Gtk2::ProgressBar->new();
    $progressBar->set_size_request( 120, 20 );
    $progressBar->set_text( "Loading" );
    $fixed->put( $progressBar, ($screen_size{"w"}/2) - (120/2), 240 );

    $window->show_all;

    my $p = 0;

    Glib::Timeout->add( 100, sub {
        $p += 5;
        $progressBar->set_fraction( $p / 100 );
        if( $p + 5 <= 100 ) {
            return 1;
        }
        else {
            print( "Done\n" );
            my $ipaddr_str = `ifconfig | grep 'inet addr'`;
            my( $ipaddr ) = $ipaddr_str =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/;
            $progressBar->set_text(  $ipaddr );
            return 0;
        }
    } );

    Gtk2->main;
}

# threads->new( \&initDisplay );

use FindBin;
use lib "$FindBin::Bin";
use XBDB;
use Digest::MD5 qw( md5 );

$| = 1;			# Flush Output

my %clients;	    # Pool of Clients
my @messages;	    # Pool of Messages
my $xbee;		    # Handler to XBee Module
my $locked:shared;  # Mutext Lock Object

my $LISTENING_PORT = 80; # Listening Port

# Initialize Http (Port 80) Server
POE::Component::Server::TCP->new(
	Alias			=> "dserv",
	Port			=> $LISTENING_PORT,
	ClientFilter	=> 'POE::Filter::HTTPD',

	InlineStates => { 
		send => sub {
            eval {
                my( $heap, $session, $response, $disconnect ) = @_[HEAP, SESSION, ARG0, ARG1];
                my $session_id = $session->ID;
                logger( "INFO", "Client #$session_id: (Disconnect:" . ($disconnect?"Yes":"No") .")" );
                $heap->{client}->put($response);
                if( $disconnect ) {
                    $_[KERNEL]->yield("shutdown");
                }
            };

            if( $@ ) {
                logger( "ERROR", "While sending request to client: $@" );
            }
		}
	},

	ClientConnected => sub {
		my $session_id = $_[SESSION]->ID;
		$clients{$session_id} = { session_id => $session_id };
		logger( "INFO", "Client#$session_id connected" );
	},

	ClientError => sub {
		my $session_id = $_[SESSION]->ID;
		delete $clients{$session_id};
		logger( "ERROR", "Client#$session_id disconnected on ERROR" );
	},

	ClientDisconnected => sub {
		my $session_id = $_[SESSION]->ID;
		delete $clients{$session_id};
		logger( "INFO", "Client#$session_id disconnected" );
	},

	ClientInput => sub {
        eval {
            my( $kernel, $session, $request, $heap ) = @_[KERNEL, SESSION, ARG0, HEAP];
            
            my $session_id	= $session->ID;
            my $client		= $clients{$session_id};

			# Filter::HTTPD sometimes generates HTTP::Response objects.
			# They indicate (and contain the response for) error that occur
			# while parsing the client's HTTP request.  It's easiest to send
			# the responses as they are and finish up
			if( $request->isa("HTTP::Response") ) {
				logger( "INFO", "Some error" );
				$heap->{client}->put( $request );
				$kernel->yield( "shutdown" );
				return;
			}

			if( $request->uri eq "/" ) {
				logger( "[#$session_id] Sending welcome html" );
				my $response = HTTP::Response->new(200);
				$response->push_header('Content-type', 'text/html');
				$response->content( getStaticContent("Welcome.html") );
				$heap->{client}->put( $response );
				$kernel->yield( "shutdown" );
				return;
			}
			elsif( $request->uri eq "/publish" ) {
				
				if( !exists $client->{publisher} )
				{
		            logger( "INFO", "[#$session_id] is logged in as a publisher" );
					$client->{publisher} = 1;
				}
				elsif( $request->method eq "POST" && $request->header("Content-Length") * 1 > 0 )
				{
					logger( "INFO", "Broadcasting message: " . $request->content );
			        broadcastAll( $session_id, $request->content );
				}
			}
			elsif( $request->uri eq "/socket" ) {
				logger( "INFO", "[#$session_id] Request:\n" . $request->as_string );

				$client->{websocket} = 1;
				my $srv = $request->header("origin") . $request->uri;
				$srv =~ s/http/ws/;
				my $response = HTTP::Response->new(101, "WebSocket Protocol Handshake" );
				$response->push_header( "Upgrade", "WebSocket" );
				$response->push_header( "Connection", "Upgrade" );
				$response->push_header( "Sec-WebSocket-Origin", $request->header("origin") );
				$response->push_header( "Sec-WebSocket-Location", $srv );
				
				my $key1 = $request->header("Sec-WebSocket-Key1");
				my $key2 = $request->header("Sec-WebSocket-Key2");
				my $key3 = $request->content;
				
				$response->content( getHandShakeKey( $key1, $key2, $key3 ) );

				$heap->{client}->put( $response );

				# keep the connection open
				logger( "INFO", "Keep the connection open :)" );
			}
			elsif( $request->uri =~ m/\/(send|sendhex)\/([0-9A-F]{16})\/(.*)/i ) {
				my( $type, $dest64, $payload ) = ( $1, $2, $3 );
				logger( "INFO", "Sending '$payload' to '$dest64' (".length($dest64).")" );
				$payload = pack( "H*", $payload ) if lc($type) eq "sendhex";
				$dest64 = pack( "H*", $dest64 );
				$xbee->transmit_request( $dest64, $payload);
				
				my $response = HTTP::Response->new(200);
				$response->push_header('Content-type', 'text/html');
				$response->content( getStaticContent("DataSent.html") );
				$heap->{client}->put( $response );
				$kernel->yield( "shutdown" );
				return;
			}
			elsif( $request->uri eq "/discover" ) {
				logger( "INFO", "Sending Node Discovery Command to get replies from end-nodes" );
				$xbee->at_command("ND");
			}
			elsif( -f "./htdocs" . $request->uri ) {
				logger( "INFO", "[#$session_id] Requested static file: " . $request->uri );
				my $response = HTTP::Response->new(200);
				my $file = $request->uri;
				my( $ext ) = $file =~ /\.([A-Z0-9]+)$/i;
				$response->push_header('Content-type', $MIME->{$ext} );
				$response->content( getStaticContent( $request->uri ) );
				$heap->{client}->put( $response );
				$kernel->yield( "shutdown" );
				return;
			}
			else {
				logger( "INFO", "I don't know what you're asking for:\n" . $request->as_string );
				$_[KERNEL]->yield("shutdown");
			}
		
        };

        if( $@ ) {
            logger( "ERROR", "Error while processing user request: $@" );
            $_[KERNEL]->yield("shutdown");
        }
    }
);

logger( "INFO", "Process started on port 80" );

#---------------------------------------------
sub broadcastAll
#---------------------------------------------
{
	my( $sender, $response ) = @_;

	foreach my $user (keys %clients ) {
		next if (defined $sender && $user == $sender);
		my $client = $clients{$user};
		next if exists $client->{publisher};
		next if !exists $client->{websocket};
		my $respobj = {
			raw_message => 1,
			message => "\x00".$response."\xFF"
		};
		POE::Kernel->post($user => send => $respobj );
	}
}

my $path = "./htdocs";

#---------------------------------------------
sub getStaticContent
#---------------------------------------------
{
	my( $file ) = @_;
	my( $ext ) = $file =~ /\.([A-Z0-9]+)$/i;
	my $size = -s "$path/$file";
	
	open FH, "< $path/$file";
	my $data = "";
	while( <FH> ) {
		$data .= $_;
	}
	close FH;
	return $data;
}

#---------------------------------------------
# Generates a handshake key according to draft 76
#---------------------------------------------
sub getHandShakeKey
{
	my( $key1, $key2, $key3 ) = @_;
	
	my $numkey1 = $key1; $numkey1 =~ s/[^\d]//g; $numkey1 *= 1;
	my $numkey2 = $key2; $numkey2 =~ s/[^\d]//g; $numkey2 *= 1;
	my $spaces1 = $key1; $spaces1 =~ s/[^\ ]//g; $spaces1 = length( $spaces1 );
	my $spaces2 = $key2; $spaces2 =~ s/[^\ ]//g; $spaces2 = length( $spaces2 );
	my $num1 = pack( "N", $numkey1 / $spaces1 );
	my $num2 = pack( "N", $numkey2 / $spaces2 );
	my $key = md5( $num1, $num2, $key3 );

	logger( "DEBUG", join "\n",
		"key1: $key1",
		"key2: $key2",
		"key3: $key3",
		"numkey1: $numkey1",
		"numkey2: $numkey2",
		"spaces1: $spaces1",
		"spaces2: $spaces2",
		"int1: $num1",
		"int2: $num2",
		"key: $key"
	);

	return $key;
}

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

	my $time = time2str( "%Y/%m/%d %H:%M:%S %Z", time() );

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

#---------------------------------------------
sub hex2ascii
#---------------------------------------------
# Plain perl function that converts hex string to real hex values
{
	return pack( "H*", shift );
}

sub enrichNodeData
{
    my( $frame, $xbdb ) = @_;
    my $rs = $xbdb->execQuery( "SELECT * FROM Node WHERE serial=?", $frame->{serial} );
    $rs->each( sub {
        my( $hash ) = @_;
        $frame->{nodeInfo} = $hash;
    });
}

# Create
$xbee = Xbee::API->new( { port => '/dev/ttyUSB0', debug => 0, speed => 19200 } );

use HTTP::Request;

threads->new(sub {
	
	logger( "INFO", "Initializing database" );
	my $xbdb = new XBDB( "localhost", "xbdb", "xbdb", "_xbdb" );
	
	logger( "INFO", "Waiting 3 seconds for POE Initialization" );
	sleep(3); # Wait for POE to being

	logger( "INFO", "Connecting to port $LISTENING_PORT" );
	my $remote = IO::Socket::INET->new(
		Proto => "tcp",
		PeerAddr => "localhost",
		PeerPort => $LISTENING_PORT
	) or die( "FATAL: Failed to establish TCP/IP Connection at port $LISTENING_PORT" );

	logger( "INFO", "Connected to port $LISTENING_PORT" );
	logger( "INFO", "Setting connection type to PUBLISHER" );
	print $remote "GET /publish HTTP/1.1\r\n\r\n";

	logger( "INFO", "Sending Node Discovery Command to get replies from end-nodes" );
	$xbee->at_command("ND");
    # $xbee->transmit_request( "\x0013A200406292D4", "L0H" );

	my $http_request = HTTP::Request->new("POST", "/publish");


	while (1) {
		my $frame = $xbee->read_api;

		# print Dumper( $frame );
		if( exists $frame->{type} ) {
			if( $frame->{type} == 0x80 ) {
				$xbdb->storeRxFrame( $frame );
				
				# Now ... let subscribers be aware of this change!
				$frame->{type} = "RxResponse";
                enrichNodeData( $frame, $xbdb );
				my $msg = to_json( $frame ) . "\r\n";
				$http_request->content( $msg );
				$http_request->header( "Content-Length" => length( $msg ) );
				# logger( "INFO", "Sent: " . $http_request->as_string );
				print $remote $http_request->as_string;
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
            else {
                logger( "INFO", "0x" . unpack( "H*", $frame->{raw_data} ) );
            }
		}
	}
} );

POE::Kernel->run();

exit 0;
