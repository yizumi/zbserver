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

use POE;
use POE::Component::Server::TCP;
use JSON;
use Date::Format qw( time2str );
use Xbee::API;
use threads;
# use threads::shared;

use FindBin;
use lib "$FindBin::Bin";
use XBDB;
use HttpRequest;

$| = 1;			# Flush Output

my %clients;	    # Pool of Clients
my @messages;	    # Pool of Messages
my $xbee;		    # Handler to XBee Module
my $locked:shared;  # Mutext Lock Object

my $LISTENING_PORT = 80; # Listening Port

# Initialize Http (Port 80) Server
POE::Component::Server::TCP->new(
	Alias	=> "zserv",
	Port	=> $LISTENING_PORT,
	InlineStates => { 
		send => sub {
            eval {
                my( $heap, $session, $message, $disconnect ) = @_[HEAP, SESSION, ARG0, ARG1];
                my $session_id = $session->ID;
                logger( "DEBUG", "Client #$session_id: $message (Disconnect:" . ($disconnect?"Yes":"No") .")" );
                $heap->{client}->put($message);
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
		$clients{$session_id} = new HttpRequest($session_id);
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
            my( $kernel, $session, $input, $heap ) = @_[KERNEL, SESSION, ARG0, HEAP];
            
            my $session_id	= $session->ID;
            my $client		= $clients{$session_id};

            logger( "DEBUG", "Client#$session_id sent $input" );
            
            # If the incoming message is something out of ordinary, appendHeader would return false.
            if( !$client->appendHeader( $input ) ) {
                $_[KERNEL]->yield("shutdown");
                return;
            }

            # Continue on the incoming request is still coming in
            return if( !$client->isReady() );
            
            if( $client->{mode} eq "publisher" ) {
                logger( "DEBUG", "Client#$session_id is logged in as a publisher" );
                broadcastAll( $session_id, $input ) unless $input eq "PUBLISHER";
            }
            elsif( $client->{mode} eq "subscriber" ) {
                logger( "DEBUG", "Client#$session_id URI Request: " . $client->{uri} );
                if( $client->{uri} eq "/" ) {
                    logger( "Client#$session_id Sending welcome html" );
                    POE::Kernel->post( $session_id => send => $client->getStaticContent("Welcome.html"), 1 );
                }
                elsif( $client->{uri} eq "/subscribe" ) {
                    logger( "DEBUG", "Leaving the connection open..." );
                    POE::Kernel->post( $session_id => send => $client->getSubsriptionHeader() );
                    logger( "DEBUG", "Query String: ".$client->{queryString} );
                    logger( "DEBUG", "Client#$session_id Last Message id: " . $client->{lastMessageIndex} );
                    if( $client->{lastMessageIndex} == -1 ) {
                        $client->{lastMessageIndex} = scalar(@messages) - 1;
                    }
                    sendInitMessage( $session_id );
                }
                elsif( $client->{uri} eq "/send" ) {
                    logger( "INFO", "I got: " . $client->{queryString} );
                    my( $type ) = $client->{queryString} =~ /type=([A-Z]+)/i;
                    my( $dest64 ) = $client->{queryString} =~ /dest64=([0-9A-F]{16})/i;
                    my( $payload ) = $client->{queryString} =~ /payload=([^&]+)/;
                    $dest64 = pack( "H*", $dest64 );
                    $payload = pack( "H*", $payload ) if uc($type) eq "HEX";
                    logger( "INFO", "Sending '$payload' to '$dest64' (".length($dest64).")" );
                    $xbee->transmit_request( $dest64, $payload);
                    POE::Kernel->post( $session_id => send => $client->getStaticContent("DataSent.txt"), 1 );
                }
                elsif( -f "./htdocs/" . $client->{uri} ) {
                    logger( "INFO", "Static file: " . $client->{uri} );
                    POE::Kernel->post( $session_id => send => $client->getStaticContent($client->{uri}), 1 );
                }
                else {
                    logger( "INFO", "I don't know what you're asking for" );
                    $_[KERNEL]->yield("shutdown");
                }
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
	my( $sender, $message ) = @_;
    my $msg = from_json( $message );
    $msg->{messageId} = scalar(@messages);
    $msg->{sendTime} = time2str( "%Y-%m-%dT%H:%M:%SZ%Z", time() );
    push( @messages, $msg );
	broadcast( $sender );
}

#---------------------------------------------
sub broadcast
#---------------------------------------------
{
    my( $sender ) = @_;

	my $count_send = 0;

	foreach my $user (keys %clients ) {
		next if defined $sender && $user == $sender;
		my $client = $clients{$user};
		next if $client->{mode} ne "subscriber"; # Keep subscribers connected
        $count_send += sendUnpublished( $client );

		#if( $client->isReady() ) {
		#	if( ($client->{lastMessageIndex} + 1 ) < scalar(@messages) ) {
        #       my $array_to_send = ();
        #       my $endIndex = scalar( @messages ) - 1; # Calculate end index first
        #       my $startIndex = exists $client->{lastMessageIndex} ? $client->{lastMessageIndex} + 1 : $endIndex;
        #       # logger( "INFO", "Start Index: $startIndex" );
        #       # logger( "INFO", "End Index: $endIndex" );                
        #       # logger( "INFO", ($startIndex..$endIndex) );
        #       grep { push @$array_to_send, $messages[$_] } ($startIndex..$endIndex);
        #       my $message = to_json($array_to_send);
        #       logger( "INFO", "Sending messages $startIndex through $endIndex to Client#$user\n=====\n$message\n=====" );
        #       $client->{lastMessageIndex} = scalar(@messages);
        #       $client->{state} = "DISCONNECT";
        #       POE::Kernel->post($user => send => $message, 1 );
        #       $count_send++;
        #   }
		#}
	}

	logger( "INFO", $count_send ? "Sent to $count_send clients" : "No one is connected" );
}

#---------------------------------------------
sub sendInitMessage
#---------------------------------------------
# Send Unpublished Messages on startup -- disconnect if there is any
{
	my( $client_id ) = @_;
	# Assumes this is a subscriber
	my $client = $clients{$client_id};
    my $count_send = sendUnpublished( $client );
    logger( "INFO", $count_send ? "Sent to $count_send clients" : "No one is connected" );
	return $count_send;
}

sub sendUnpublished
{
    lock( $locked );
    logger( "INFO", "+++ Locked..." );
    my( $client ) = @_;
    my $count_send = 0;
    my $msg_count = scalar(@messages);

    if( $client->isReady() ) {
        if( ($client->{lastMessageIndex} + 1 ) < $msg_count ) {
            # Find out what this user is missing
            my $array_to_send = ();
            my $endIndex = $msg_count - 1; # Calculate end index first
            my $startIndex = exists $client->{lastMessageIndex} ? $client->{lastMessageIndex} + 1 : $endIndex;
            # logger( "INFO", "Start Index: $startIndex" );
            # logger( "INFO", "End Index: $endIndex" );
            # logger( "INFO", ($startIndex..$endIndex) );
            grep { push @$array_to_send, $messages[$_] } ($startIndex..$endIndex);
            my $message = to_json($array_to_send);
            logger( "DEBUG", "Sending messages $startIndex through $endIndex to Client#$client->{client_id}\n=====\n$message\n=====" );
            $client->{lastMessageIndex} = $msg_count;
            $client->{state} = "DISCONNECT";
            POE::Kernel->post($client->{client_id} => send => $message, 1 );
            $count_send++;
        }
        else {
            logger( "INFO", "Client#$client->{client_id} is waiting for messageId > $client->{lastMessageIndex} (Current: $msg_count)" ) ;
        }
    }
    logger( "INFO", "+++ Unlocked" );
    return $count_send;
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
	print $remote "PUBLISHER\n";

	logger( "INFO", "Sending Node Discovery Command to get replies from end-nodes" );
	$xbee->at_command("ND");
    # $xbee->transmit_request( "\x0013A200406292D4", "L0H" );

	while (1) {
		my $frame = $xbee->read_api;

		# print Dumper( $frame );
		if( exists $frame->{type} ) {
			if( $frame->{type} == 0x80 ) {
				$xbdb->storeRxFrame( $frame );
				
				# Now ... let subscribers be aware of this change!
				$frame->{type} = "RxResponse";
                enrichNodeData( $frame, $xbdb );
				my $msg = to_json( $frame ) . "\n";
				logger( "INFO", "Sending: $msg" );
                # delete $frame->{raw_data};
				print $remote $msg;

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
