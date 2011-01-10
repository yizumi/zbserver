
	{
		package XBDB;

		use FindBin;
		use lib "$FindBin::Bin";
		use ResultSet;
		use DBI;

		sub new
		{
			my( $klass, $host, $database, $user, $pass ) = @_;
			my $dbh = DBI->connect("DBI:mysql:database=$database;host=$host", $user, $pass);
			
			my $obj = bless {
				dbh => $dbh,
                user => $user,
                pass => $pass,
                database => $database,
                host => $host
			}, $klass;

			$obj->initDatabase();
			return $obj;
		}

		sub initDatabase
		{
			my( $self ) = @_;
			$self->execUpdate( qq[
				CREATE TABLE IF NOT EXISTS Node(
					serial varchar(16) PRIMARY KEY,
					my varchar(4) NOT NULL,
					signalStrength int NOT NULL,
					deviceId varchar(20) NOT NULL,
					lastUpdate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
					deviceType varchar(32),
					domain varchar(64),
					site varchar(64),
					area varchar(255),
					currentState varchar(255),
					permission varchar(10),
					displayName varchar(255)
				);
			]);

			$self->execUpdate( qq[
				CREATE TABLE IF NOT EXISTS Site(
					domain varchar(64),
					site varchar(64),
					displayName varchar(255),
					PRIMARY KEY (domain,site)
				);
			]);

			$self->execUpdate( qq[
				CREATE TABLE IF NOT EXISTS RxResponse(
					id INT PRIMARY KEY AUTO_INCREMENT,
					serial varchar(16) NOT NULL,
					signalStrength int NOT NULL,
					options int NOT NULL,
					checksum boolean NOT NULL,
					resTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
					data varchar(255)
				);
			]);

			$self->execUpdate( qq[
				CREATE TABLE IF NOT EXISTS TxResponse(
					id INT PRIMARY KEY AUTO_INCREMENT,
					reqTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
					frameId int,
					serial varchar(16),
					data varchar(255),
					state varchar(8)
				);
			]);
		}

        sub tryThis
        {
            my( $self, $sub ) = @_;
            my $rv;
            for( my $i = 0 ; $i < 3; $i++ ) {
                eval {
                    $rv = $sub->();
                };
                if( $@ ) {
                    # Todo; THis needs to determine whether the error is driven out of stale connection
                    print( $@ . "\n" );
                    # Reopen the database connection
                    $self->{dbh}->disconnect();
                    delete $self->{dbh};
                    $self->{dbh} = DBI->connect("DBI:mysql:database=$self->{database};host=$self->{host}", $self->{user}, $self->{pass} );
                }
                else {
                    return $rv;
                }
            }
            return undef;
        }

		sub execUpdate
		{
			my $self = shift;
			my $sql = shift;
			my @params = @_;

            return $self->tryThis( sub {
                my $dbh = $self->{dbh};
                my $stmt = $dbh->prepare( $sql );
                for( my $i = 0; $i < scalar( @params ); $i++ ) {
                    $stmt->bind_param( $i + 1, $params[$i] ); # Funny, bind_param starts counting from 1
                }
                return $stmt->execute() or die( "Failed to run: \"$sql\" (Retrying)" );
            } );
		}

		sub execQuery
		{
			my $self = shift;
			my $sql = shift;
			my @params = @_;

            return $self->tryThis( sub {
                my $dbh = $self->{dbh};
                my $stmt = $dbh->prepare( $sql );
                for( my $i = 0; $i < scalar( @params ); $i++ ) {
                    $stmt->bind_param( $i + 1, $params[$i] ); # Funny, bind_param starts counting from 1
                }
                $stmt->execute() or die( "Failed to run: \"$sql\" (Retrying)" );
                return new ResultSet( $stmt );
            } );
		}

		sub storeRxFrame
		{
			my( $self, $frame ) = @_;
			$self->execUpdate( "INSERT INTO RxResponse ( serial, signalStrength, options, checksum, data ) VALUES (?,?,?,?,?)", 
				$frame->{serial}, $frame->{rssi}, $frame->{options}, $frame->{checksum} eq "OK" ? 1 : 0, $frame->{data} );
		}

		sub storeSite
		{
			my( $self, $domain, $site, $displayName ) = @_;
			$self->execUpdate( "INSERT INTO Site ( domain, site, displayName ) values (?,?,?)",
				$domain, $site, $displayName );
		}

		sub setNode
		{
			my( $self, $serial, $my, $db, $identifier ) = @_;
			if( $self->execUpdate( "UPDATE Node SET my = ?, signalStrength = ?, deviceId = ? , lastUpdate = CURRENT_TIMESTAMP WHERE serial = ?",
				$my, $db, $identifier, $serial ) == 0 ) {
				$self->execUpdate( "INSERT INTO Node( serial, my, signalStrength, deviceId ) VALUES (?,?,?,?)",
					$serial, $my, $db, $identifier );
			}
		}

		sub setCurrentState
		{
			my( $self, $addr64, $currentState ) = @_;
			$self->execUpdate( "UPDATE Node SET currentState = ?, lastUpdate = CURRENT_TIMESTAMP WHERE serial = ?",
				$currentState, $addr64 );
		}

		sub getCurrentState
		{
			my( $self, $addr64 ) = @_;

            $self->tryThis( sub {
                my $dbh = $self->{dbh};
                my $stmt = $dbh->prepare( "SELECT currentState FROM RxResponse WHERE address64 = ?" );
                $stmt->bind_param( 1, $addr64 );
                $stmt->execute();

                my $row;
                while( $row = $stmt->fetchrow_arrayref )
                {
                    return $row->[0];
                }
                return undef;
            } );
		}
	}

	1;