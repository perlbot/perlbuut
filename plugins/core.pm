BEGIN {
    my ($filename) = "Module/CoreList.pm";
    my ( $realfilename, $result );
  ITER: {
        foreach $prefix (@INC) {
            $realfilename = "$prefix/$filename";
            if ( -f $realfilename ) {
                $INC{$filename} = $realfilename;
                $result = do $realfilename;
                last ITER;
            }
        }
        die "Can't find $filename in \@INC";
    }
}

sub {
    my ( $said, $pm ) = @_;
    my $module = $said->{recommended_args}->[0];

    my $rev = Module::CoreList->first_release($module);
    if ($rev) {
        print "Added to perl core as of $rev";
        if ( Module::CoreList->can('removed_from') ) {
            my $rem = Module::CoreList->removed_from($module);
            print " and removed from $rem" if $rem;
        }
    }
    else {
        my @modules = Module::CoreList->find_modules(qr/$module/);

        if (@modules) {
            print 'Found', scalar @modules, ':', join ',',
              map { $_ . ' in ' . Module::CoreList->first_release($_) }
              @modules;

        }
        else {
            print "Module $module does not appear to be in core. Perhaps capitalization matters or try using the 'cpan' command to search for it.";
        }
    }
  }

__DATA__
Tells you when the module you searched for was added to the Perl Core, if it was.
