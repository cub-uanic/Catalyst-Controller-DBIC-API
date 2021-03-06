use 5.6.0;

use strict;
use warnings;

use lib 't/lib';

my $base = 'http://localhost';
my $content_type = [ 'Content-Type', 'application/x-www-form-urlencoded' ];

use RestTest;
use DBICTest;
use Test::More;
use Test::WWW::Mechanize::Catalyst 'RestTest';
use HTTP::Request::Common;
use JSON::Any;

my $mech = Test::WWW::Mechanize::Catalyst->new;
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $track = $schema->resultset('Track')->first;
my %original_cols = $track->get_columns;

my $track_url = "$base/api/rest/track/";
my $track_update_url = $track_url . $track->id;
my $tracks_update_url = $track_url;

# test invalid track id caught
{
	foreach my $wrong_id ('sdsdsdsd', 3434234) {
		my $incorrect_url = "$base/api/rest/track/" . $wrong_id;
		my $test_data = JSON::Any->Dump({ title => 'value' });
		my $req = POST( $incorrect_url, Content => $test_data );
		$req->content_type('text/x-json');
		$mech->request($req);

		cmp_ok( $mech->status, '==', 400, 'Attempt with invalid track id caught' );
		
		my $response = JSON::Any->Load( $mech->content);
		like( $response->{messages}->[0], qr/No object found for id/, 'correct message returned' );
		
		$track->discard_changes;
		is_deeply({ $track->get_columns }, \%original_cols, 'no update occurred');
	}
}

# validation when no params sent
{
	my $test_data = JSON::Any->Dump({ wrong_param => 'value' });
	my $req = POST( $track_update_url, Content => $test_data );
	$req->content_type('text/x-json');
	$mech->request($req);

	cmp_ok( $mech->status, '==', 400, 'Update with no keys causes error' );

	my $response = JSON::Any->Load( $mech->content);
	is_deeply( $response->{messages}, ['No valid keys passed'], 'correct message returned' );

	$track->discard_changes;
	is_deeply({ $track->get_columns }, \%original_cols, 'no update occurred');
}

{
	my $test_data = JSON::Any->Dump({ title => undef });
	my $req = POST( $track_update_url, Content => $test_data );
	$req->content_type('text/x-json');
	$mech->request($req);
	cmp_ok( $mech->status, '==', 200, 'Update with key with no value okay' );

	$track->discard_changes;
	isnt($track->title, $original_cols{title}, 'Title changed');
	is($track->title, undef, 'Title changed to undef');
}

{
	my $test_data = JSON::Any->Dump({ title => 'monkey monkey', 'cd' => { year => 2009 } });
	my $req = POST( $track_update_url, Content => $test_data );
	$req->content_type('text/x-json');
	$mech->request($req);

	cmp_ok( $mech->status, '==', 200, 'Update with key with value okay' );

	$track->discard_changes;
	is($track->title, 'monkey monkey', 'Title changed to "monkey monkey"');
	is($track->cd->year, 2009, 'related row updated');
}

# bulk_update existing objects
{
  # order to get a stable order of rows
  my $tracks_rs = $schema->resultset('Track')->search(undef, { order_by => 'trackid', rows => 3 });
  my $test_data = JSON::Any->Dump({ list => [map +{ id => $_->id, title => 'Track ' . $_->id }, $tracks_rs->all] });
  my $req = PUT( $tracks_update_url, Content => $test_data );
  $req->content_type('text/x-json');
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'Attempt to update three tracks ok' );

  $tracks_rs->reset;
  while (my $track = $tracks_rs->next) {
    is($track->title, 'Track ' . $track->id, 'Title changed');
  }
}

# bulk_update nonexisting objects
{
  # order to get a stable order of rows
  my $test_data = JSON::Any->Dump({ list => [map +{ id => $_, title => 'Track ' . $_ }, (1000..1002)] });
  my $req = PUT( $tracks_update_url, Content => $test_data );
  $req->content_type('text/x-json');
  $mech->request($req);
  cmp_ok( $mech->status, '==', 400, 'Attempt to update three nonexisting tracks fails' );
  my $response = JSON::Any->Load( $mech->content);
  is( $response->{success}, JSON::Any::false, 'success property returns unquoted false' );
  like( $response->{messages}->[0], qr/No object found for id/, 'correct message returned' );
}

done_testing();
