package HTML::FormFiller;
use 5.006;
use strict;
use warnings;

use Carp;
use HTML::Parser;
use HTML::Entities qw{encode_entities};
use Data::Dumper;

our $VERSION = '0.04';

=head1 NAME

HTML::FormFiller - refill html forms

=head1 DESCRIPTION

Quite often when working with user input from HTML forms it is useful to be
able to show the same form again with fields repopulated with the information
previously provided by the user.

=head1 MOTIVATION

Although there's already a module in existance to pre-populate forms when
running under CGI (L<HTML::FillInForm>) it requires a CGI object to work.

This module implements the same idea but without the dependency on
CGI/mod_perl. Simply pass in the HTML and the hash of form field data and let
the module do the rest.

=head1 SYNOPSIS

First you need some HTML markup (I<$html>), preferably with form fields in it.
You also need a hash-reference (I<$form_field_data>) containing form field data
in a I<'fieldname' =E<gt> 'fieldvalue'> format.

Assuming you have form fields called first_name, last_name and email, you
should then populate your hash as follows:

  $form_field_data = {
    'first_name' => 'John',
    'last_name'  => 'Smith',
    'email'      => 'johnsmith@hotmail.com',
  }

You would incorporate this into a script similar to the following:

  use HTML::FormFiller;

  # lots of code
  
  # prefill form fields
  $filled = HTML::FormFiller->fill({
    'html'   => $html,
    'fields' => $form_field_data
  });

  # send the output to the browser
  print "Content-type: text/html\n\n";
  print $filled;

=head1 STORING FORM DATA

There are probably many different ways to get form data into a key-value
formatted hash.  Here's one to copy-and-paste if you don't have the time to
think up your own way of doing this.

In this snippet B<$request> is an Apache::Request object. After this block is
called you'll find your form field data in B<$page_vars>. This method accounts
for fields that might return a list of values, for example a checkbox group.

  # fetch parameters from the request
  my @params = $request->param();
  foreach my $param_name (@params) {
    my @param_values = $request->param($param_name);
    # check for parameters with multiple values; e.g. check boxes
    # since $#arrayname can be -ve we can't just use if ($#array){..}
    if ($#param_values > 0) {
      # multiple values
      $page_vars->{$param_name} = \@param_values;
    }
    else {
      # single value
      $page_vars->{$param_name} = $param_values[0];
    }
  }

=cut

# the main function called, creates a new version of out object, then calls the
# function that does the actual work filling everything in
sub fill($$) {
	#my ($proto, $html, $formvars) = @_;
	my ($proto, $options) = @_;
	my ($self,$class);

	# make ourself an object so we refer to $self, my pretty
	$class = ref($proto) || $proto;
	$self = {};
	bless $self, $class;

	# make sure $options is a hash-reference
	unless (ref($options) eq 'HASH') {
		Carp::carp "Argument passed to fill() is not a hash-reference";
		return undef;
	}

	# get (at least) 'html' and 'fields' from $options
	foreach my $required (qw{ html fields }) {
		#unless (exists $options->{$required} and defined $options->{$required}) {
		unless (exists $options->{$required}) {
			Carp::carp "required option '$required' not passed to fill()";
			return undef;
		}
		# stop the value in ourself
		$self->{'options'}{$required} = $options->{$required};
	}

	# do all the re/pre-filling work, and return the html
	return $self->_fillform;
}

# this function set up our HTML::Parser options then parses the html input
sub _fillform ($) {
	my ($self) = @_;
	my ($hp);

	# create a new parser
	$hp = HTML::Parser->new(
		'api_version'	=> 3,
		# by default just store stuff
		'default_h'		=> [sub { $self->_store(@_) }, 'text'],
	);

	# handle tags
	$hp->handler('start'	=> sub { $self->_start_handler(@_); },	'text,attr,tagname');
	$hp->handler('end'		=> sub { $self->_end_handler(@_); },	'text,tagname');

	# parse the file
	$hp->parse($self->{'options'}{'html'});
	# end the stream
	$hp->eof;
	# return the html
	return $self->{'html'};
}

# this handler does nearly all of the work for the form filling
sub _start_handler {
	my ($self, $text, $attr, $tagname) = @_;
	my $formvars = $self->{'options'}{'fields'};

	# make a local copy of the form vars
	my %local_vars;
	# get a copy of the formvars, and where required encode HTML entities
	map { $local_vars{$_} = encode_entities($formvars->{$_}) } keys %$formvars;

	# initially, we're only interested in tags with a name, and a value we can
	# quite happily ignore things with no name and no value, because they're of
	# little use - no name? we're never going to see the value in a form input
	# no matching formvar and we've nothing to substiture into the value
	if (defined $attr->{'name'} and defined $local_vars{$attr->{'name'}}) {
		# is it an <input ...> field?
		# if it is we can take the appropriate action for each input type
		if ($tagname =~ /^input$/i) {
			# text, password and hidden formfields are a simple substitution
			if ($attr->{'type'} =~ /^(?:text|hidden|password)$/i) {
				# replace value="*" with our value
				unless ($text =~ s[
					\b					# word-boundary
					value\s*=\s*"		# value=" (with potential whitespace around the =
					[^"]*				# anything that's not a quote
					"					# end quote
					][value="$local_vars{$attr->{'name'}}"]ix) {
					warn "failed to substitute $local_vars{$attr->{'name'}} in: $text";
				}
			}
			elsif ($attr->{'type'} =~ /^radio$/i) {
				# deal with a radio group, or checkbox
				if ($attr->{'value'} eq $local_vars{$attr->{'name'}}) {
					# add the CHECKED="CHECKED" option
					$self->_make_checked(\$text);
				}
			}
			elsif ($attr->{'type'} =~ /^checkbox$/i) {
				# is it a list of values?
				if (ref($local_vars{$attr->{'name'}}) eq 'ARRAY') {
					# if the value for the field exists in the values list
					# then it should be checked
					if (grep {/^$attr->{'value'}$/} @{ $local_vars{$attr->{'name'}} }) {
						$self->_make_checked(\$text);
					}
				}
				# or a single value?
				else {
					# if the value matches the value passed in via the formvars
					# then we make this checked
					if ($attr->{'value'} eq $local_vars{$attr->{'name'}}) {
						$self->_make_checked(\$text);
					}
				}
			}
			# ignore submits 
			elsif ($attr->{'type'} =~ /^submit$/) {
				# do nothing
			}
			# ignore inputs of type image 
			elsif ($attr->{'type'} =~ /^image$/) {
				# do nothing
			}
			else {
				warn "UNRECOGNISED input tag: $tagname; $attr->{'type'}; $attr->{'name'}";
			}
		}
		# is it a select tag? if so, we want to make a note
		elsif ($tagname =~ /^select$/i) {
			$self->{'select_list'} = $attr->{'name'};
		}
		# is it a TEXTAREA? we need to append the field value to the tag to we have something
		# like "<textarea>" --> "<textarea>value"
		elsif ($tagname =~ /^textarea$/i) {
			$text .= $local_vars{$attr->{'name'}};
		}
	}

	# is it an option tag? we don't care about "name"
	elsif ($tagname =~ /^option$/i) {
		# if we're in a SELECT list, and we have a value for that SELECT list
		# that matches our OPTION tag we want to add SELECTED to the OPTION tag
		if (defined $self->{'select_list'}) {
			# we're looking for the value of our select_list to match the value
			# of the OPTION tag, if we get that then we want to set SELECTED
			# for the option
			if ($attr->{'value'} eq $local_vars{$self->{'select_list'}}) {
				# replace value="*" with our value
				unless ($text =~ s[
					>$					# the closing > for the tag
					][ SELECTED="SELECTED">]ix) {
					warn "failed to substitute $local_vars{$attr->{'name'}} in: $text";
				}
			}
		}
	}
	
	# store the (possibly altered) text
	$self->_store($text);
}

# the end handler only exists to help us deal with select lists
sub _end_handler {
	my ($self, $text, $tagname) = @_;

	# if we're finishing a select_list undefine $select_list
	if ($tagname =~ /^select$/i) {
		delete $self->{'$select_list'};
	}

	# store the (possibly altered) text
	$self->_store($text);
}

# we want to store all of the page text to return later
sub _store {
	my ($self,$text) = @_;

	$self->{'html'} .= $text;
}

# pass in a scalar reference and add the CHECKED="CHECKED" option before the closing >
sub _make_checked($$) {
	my ($self, $textref) = @_;

	# make the substitution - return the number of substitions made
	return $$textref =~ s/>$/ CHECKED="CHECKED">/;
}

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
