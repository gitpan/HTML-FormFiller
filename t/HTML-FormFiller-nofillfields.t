# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl HTML-FormFiller.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 9;
BEGIN { use_ok('HTML::FormFiller') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


##
## We expect all these tests to leave the fields alone (because the
## names/values don't match, or aren't defined)
##


# global variables
our ($filler, $html, $fields, $filled_html);
our ($tests);

# a function to fill the html we've prepared, with our fields
sub do_fill {
	$filled_html = HTML::FormFiller->fill(
		{
			'html'		=> $html,
			'fields'	=> $fields,
		}
	);
}

# The number of tests here is the number of elements in $tests
TESTS: {
	# some simple tests
	$tests = [
		{
			'field_type'	=> 'text',
			'field_name'	=> 'textfield',
			'field_value'	=> 'MyTextField',
		},
		{
			'field_type'	=> 'hidden',
			'field_name'	=> 'hiddenfield',
			'field_value'	=> 'MyHiddenField',
		},
		{
			'field_type'	=> 'password',
			'field_name'	=> 'passwordfield',
			'field_value'	=> 'MyPasswordField',
		},
	];

	# run through the tests defined above
	foreach my $test (@$tests) {
		# set the html for the field that we're going to test
		$html = qq[<input type="$test->{field_type}" name="$test->{field_name}" value="">];
		# make sure we have the value defined in our fields hash - used for passing to HTML::FormFiller
		#$fields->{ $test->{'field_name'} } = $test->{'field_value'};
		# fill the field
		do_fill;
		# check we got the expected result
		ok($filled_html ne qq[<input type="$test->{field_type}" name="$test->{field_name}" value="$test->{field_value}">], "prefill $test->{field_name}");
	}
}

# checkbox test - single checkbox
$html = q[<input type="checkbox" value="abc" name="check_me">];
$fields->{'check_me'} = 'abcdef';	# incorrect value to match check box value
#$filled_html = HTML::FormFiller->fill($html, $fields);
do_fill;
ok($filled_html ne q[<input type="checkbox" value="abc" name="check_me" CHECKED="CHECKED">], 'checkbox');

# checkbox test - checkbox group
$html = q[<input type="checkbox" value="abc" name="check_me"><input type="checkbox" value="xyz" name="check_me">];
$fields->{'check_me'} = ['abcdef','uvwxyz'];	# incorrect values to match check box value
#$filled_html = HTML::FormFiller->fill($html, $fields);
do_fill;
ok($filled_html ne q[<input type="checkbox" value="abc" name="check_me" CHECKED="CHECKED"><input type="checkbox" value="xyz" name="check_me" CHECKED="CHECKED">], 'checkbox group');

# select list
$html = q[<select name="select_list"><option value="1">One</option><option value="2">Two</option><option value="3">Three</option></select>];
$fields->{'select_list'} = '-'; # pick a value not in the list
#$filled_html = HTML::FormFiller->fill($html, $fields);
do_fill;
ok($filled_html ne q[<select name="select_list"><option value="1">One</option><option value="2" SELECTED="SELECTED">Two</option><option value="3">Three</option></select>]);

# textarea - single line input
$html = q[<p><textarea name="areaoftext"></textarea></p>];
#$fields->{'areaoftext'} = 'One Two Three';
#$filled_html = HTML::FormFiller->fill($html, $fields);
do_fill;
ok($filled_html ne q[<p><textarea name="areaoftext">One Two Three</textarea></p>]);

# textarea - multiple line input
$html = q[<p><textarea name="areaoftext"></textarea></p>];
#$fields->{'areaoftext'} = 'One
#Two
#Three';
#$filled_html = HTML::FormFiller->fill($html, $fields);
do_fill;
ok($filled_html ne q[<p><textarea name="areaoftext">One
Two
Three</textarea></p>]);


