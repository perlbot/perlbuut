use POE::Component::IRC::Common qw/l_irc/;
use DBI;
use DBD::SQLite;

no warnings 'void';

sub {
	my( $said, $pm ) = @_;
	my $body = $said->{body};
	s/^\s+//, s/\s+$// for $body;

	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=var/karma.db",
		"",
		"",
		{ RaiseError => 1, PrintError => 0 }
	);

  if ($body =~ /me\s*(-?\d+)/) {
     my $count = $1;
     my $who = l_irc $said->{name};
     my $sth;
     if ($count > 0) {
       $sth = $dbh->prepare("SELECT author, kars FROM (SELECT author, sum(operation) as kars FROM karma WHERE author <> 'perlbot' AND subject = ? GROUP BY author) AS karmsub ORDER BY kars DESC LIMIT ?");
     } else {
       $sth = $dbh->prepare("SELECT author, kars FROM (SELECT author, sum(operation) as kars FROM karma WHERE author <> 'perlbot' AND subject = ? GROUP BY author) AS karmsub ORDER BY kars ASC LIMIT ?");
     }

     $sth->execute($who, abs $count);

     while (my $row = $sth->fetchrow_arrayref()) {
        my $subject=$row->[0];
        my $karma = $row->[1];

        print "$subject: $karma ";
     }
  } elsif ($body =~ /abs\s*(-?\d+)/) {
     my $count = $1;
     my $sth;
     if ($count > 0) {
       $sth = $dbh->prepare("SELECT author, kars FROM (SELECT author, sum(abs(operation)) as kars FROM karma WHERE author <> 'perlbot' GROUP BY author) AS karmsub ORDER BY kars DESC LIMIT ?");
     } else {
       $sth = $dbh->prepare("SELECT author, kars FROM (SELECT author, sum(abs(operation)) as kars FROM karma WHERE author <> 'perlbot' GROUP BY author) AS karmsub ORDER BY kars ASC LIMIT ?");
     }

     $sth->execute(abs $count);

     while (my $row = $sth->fetchrow_arrayref()) {
        my $subject=$row->[0];
        my $karma = $row->[1];

        print "$subject: $karma ";
     }
  } elsif ($body =~ /most\s*(-?\d+)(\s*karma)?/){
     my $count = $1;
     my $sth;
     if ($count > 0) {
       $sth = $dbh->prepare("SELECT author, kars FROM (SELECT author, sum(operation) as kars FROM karma WHERE operation > 0 AND author <> 'perlbot' GROUP BY author) AS karmsub ORDER BY kars DESC LIMIT ?");
     } else {
       $sth = $dbh->prepare("SELECT author, kars FROM (SELECT author, sum(operation) as kars FROM karma WHERE operation < 0 AND author <> 'perlbot' GROUP BY author) AS karmsub ORDER BY kars ASC LIMIT ?");
     }

     $sth->execute(abs $count);

     while (my $row = $sth->fetchrow_arrayref()) {
        my $subject=$row->[0];
        my $karma = $row->[1];

        print "$subject: $karma ";
     }
  } elsif ($said->{body} =~ /\s*(-?\d+)(\s*karma)?/) {
     my $count = $1;
     my $sth;
     if ($count > 0)
     {
       $sth = $dbh->prepare("SELECT subject, kars FROM (SELECT subject, sum(operation) as kars FROM karma GROUP BY subject) AS karmsub ORDER BY kars DESC LIMIT ?");
     }
     else
     {
       $sth = $dbh->prepare("SELECT subject, kars FROM (SELECT subject, sum(operation) as kars FROM karma GROUP BY subject) AS karmsub ORDER BY kars ASC LIMIT ?");
     }

     $sth->execute(abs $count);

     while (my $row = $sth->fetchrow_arrayref())
     {
        my $subject=$row->[0];
        my $karma = $row->[1];

        print "$subject: $karma ";
     }
  }  else  {
     print "usage is: top/bottom \\d+ karma";
  }
};

__DATA__
karmatop <number>; returns the top or bottom karma for a number of things.  to get bottom karma use negative numbers.
