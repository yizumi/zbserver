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

use Gtk2 -init;
use Gnome2::Canvas;
use POE qw( Component::Client::HTTP );
use HTTP::Request;
use HTTP::Headers;
use threads;
use Carp qw( confess );

$SIG{__DIE__} = \&confess;
# $SIG{__WARN__} = \&confess;

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
	return 0;
}

exit( initDisplay() );
