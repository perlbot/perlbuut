package Jplugin;

use 5.008008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Jplugin ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	jplugin	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Jplugin', $VERSION);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Jplugin - J evaluation plugin for buubot

=head1 SYNOPSIS

  use Jplugin;
  # ...
  # inside a safe-executed sub:
  Jplugin::jplugin($code);

=head1 DESCRIPTION

The I<jplugin> function executes a j statement and prints the result
(in linear form) or the error message to the standard output.  
It should be called inside a safe execution environment, after a fork.  
The only argument is a string containing a single J command.

=head1 REQUIREMENTS

You need to get the J interpreter for this module,
specifically the shared library I<libj601.so>.  
You can download the interpreter from 
I<http://www.jsoftware.com/stable.htm>.

=head1 AUTHOR

Zsban Ambrus, E<lt>ambrus@math.bme.huE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Zsban Ambrus

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

The J interpreter, however, has its own, stricter terms of copying.

=cut
