package HTML::FormFiller;
use 5.006;
use strict;
use warnings;

use Carp;
use HTML::Parser;
use HTML::Entities qw{encode_entities};
use Data::Dumper;

our $VERSION = '0.05';

=head1 NAME

HTML::FormFiller - deprecated in favour of HTML::FillInForm

=head1 DESCRIPTION

I was mistaken about HTML::FillInForm. Time to deprecate in favour of the
established module.

HTML::FillInForm accepts any of the following:

- An object which provides a param() method.  This can be a CGI.pm object,
an Apache::Request object, _or_ an object of one's own creation.  I do the
latter in some of my applications, and it works great.

- A hash reference of data.

=cut

BEGIN { die "This package has been deprecated in favor of HTML::FillInForm" }

=head1 AUTHOR

Chisel Wright, E<lt>chisel@herlpacker.co.ukE<gt>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2004 by Chisel Wright

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut

# be true
1;
