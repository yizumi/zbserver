{

	package HttpRequest;
	use JSON;

	my $init = 0;
	my $cache_subscription_header = "Content-Type: application/json\nCache-Control: non-cache\nProgma: no-cache\n\n";
    my $path = "./htdocs";

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
    };

	sub init
	{
		open FH, "< $path/SubscriptionHeader.html";
		while( <FH> ) {
			$cache_subscription_header .= $_;
		}
		close FH;
	}

	sub new
	{
		my( $klass, $client_id ) = @_;

		if( !$init ) {
			init();
			$init = 1;
		}
		
		my %headers = ();

		return bless {
            client_id       => $client_id,
			mode			=> undef,   # listener | publisher
			state			=> "EMPTY", # EMPTY | HEADER | READY | DISCONNECT
			command			=> undef,   # e.g. "GET / HTTP/1.1"
			method			=> undef,   # GET | POST
			uri				=> undef,   # e.g. "/", "/submit", "/subscribe"
			http_version	=> undef,   # e.g. "1.1"
			headers => \%headers,
			lastMessageIndex => -1
		}, $klass;
	}

	sub appendHeader
	{
		my( $self, $input ) = @_;
		return 1 if( $self->{state} eq "READY" );

		if( $self->{state} eq "EMPTY" )
		{
			if( $input =~ m/(GET|POST) ([^\s]+) HTTP\/([0-9.]+)/i )
    		{
				$self->{mode}           = "subscriber";
				$self->{command}        = trim($0);
				$self->{method}         = uc(trim($1));
				$self->{uri}            = trim($2);
				$self->{http_version}   = trim($3);

				if( $self->{uri} =~ /(.*)\?(.*)/) {
					$self->{uri} = $1;
					$self->{queryString} = $2;

					if( $self->{uri} eq "/subscribe" && $self->{queryString} =~/lastMessageIndex=([0-9]+)/ ) {
						$self->{lastMessageIndex} = $1 * 1;
					}
                }

				$self->{state} = "HEADER";
				return 1;
			}
			elsif( trim($input) eq "PUBLISHER" )
			{
				$self->{mode}   = "publisher";
                $self->{state}  = "READY";
			}
		}
		elsif( $self->{state} eq "HEADER" ) {
			if( $input =~ m/^([^:]+):(.*)/ ) {
				my $key = trim($1);
				my $value = trim($2);
				$self->{headers}->{lc($key)} = $value;
				return 1;
			}
			elsif( trim($input) eq "" ) {
                if( $self->{method} eq "GET" ) {
                    # print("**** GET ... turning into READY\n" );
    				$self->{state} = "READY";
	    			return 1;
                }
                elsif( $self->{method} eq "POST" ) {
                    # print("**** POST ... turning into BODY\n" );
                    $self->{state} = "BODY";
                    $self->{body} = "";
                    return 1;
                }
			}
		}
        elsif( $self->{state} eq "BODY" ) {
            $self->{body} .= $input;
            print( "*** K... seeing $input\n" );
            if( length($self->{body}) >= $self->{headers}->{"content-length"} || index($input,"\x00") > -1 ) {
                print( "*** K... Done!\n" );
                $self->{state} = "READY";
            }
            else {
                print( "*** Still reading..." . length($self->{body}) . " out of " . $self->{headers}->{"content-length"} . " bytes\n" );
            }
            return 1;
        }
		else {
			return 0;
		}
	}

	sub isHeader
	{
		my( $self, $input ) = @_;
		return $input =~ m/(GET|POST) ([^\s]+) HTTP\/([0-9.]+)/i;
	}

	sub isReady
	{
		my( $self ) = @_;
		return $self->{state} eq "READY";
	}

	sub getStaticContent
	{
        my( $self, $file ) = @_;
        my( $ext ) = $file =~ /.*\.([A-Z0-9]+)^/i;
        my $size = -s "$path/$file";
        my $data = "HTTP/".$self->{http_version}." 200 OK\nContent-Type: ".
            $MIME{$ext}."\nContent-Length: $size\nCache-Control: non-cache\nProgma: no-chace\n\n";
		open FH, "< $path/$file";
		while( <FH> ) {
			$data .= $_;
		}
		close FH;
		return $data;
	}

	sub getSubsriptionHeader
	{
		my( $self ) = @_;
		return "HTTP/".$self->{http_version} . " 200 OK\n" . $cache_subscription_header;
	}

	sub toString
	{
		my( $self ) = @_;
		my $obj = {
			command => $self->{command},
			method => $self->{method},
			uri => $self->{uri},
			http_version => $self->{http_version},
			headers => $self->{headers}
		};
		return to_json( $obj );
	}

	sub trim
	{
		my $string = shift;
		$string =~ s/^\s+//;
		$string =~ s/\s+$//;
		return $string;
	}
}

1;