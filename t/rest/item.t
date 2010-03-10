use 5.6.0;

use strict;
use warnings;

use lib 't/lib';

my $base = 'http://localhost';

use RestTest;
use DBICTest;
use URI;
use Test::More;
use Test::WWW::Mechanize::Catalyst 'RestTest';
use HTTP::Request::Common;
use JSON::Any;

my $mech = Test::WWW::Mechanize::Catalyst->new;
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $artist_view_url = "$base/api/rest/artist/";

{
    my $id = 1;
    my $req = GET( $artist_view_url . $id, undef, 'Accept' => 'application/json' );
    $mech->request($req);
    cmp_ok( $mech->status, '==', 200, 'open attempt okay' );
    my %expected_response = $schema->resultset('Artist')->find($id)->get_columns;
    my $response = JSON::Any->Load( $mech->content);
    is_deeply( $response, { data => \%expected_response, success => 'true' }, 'correct data returned' );
}

{
    my $id = 5;
    my $req = GET( $artist_view_url . $id, undef, 'Accept' => 'application/json' );
    $mech->request($req);
    cmp_ok( $mech->status, '==', 400, 'open attempt not ok' );
    my $response = JSON::Any->Load( $mech->content);
    is($response->{success}, 'false', 'not existing object fetch failed ok');
    like($response->{messages}->[0], qr/^No object found for id/, 'error message for not existing object fetch ok');
}

my $track_view_url = "$base/api/rest/track/";

{
    my $id = 9;
    my $req = GET( $track_view_url . $id, undef, 'Accept' => 'application/json' );
    $mech->request($req);
    cmp_ok( $mech->status, '==', 200, 'got track with datetime object okay' );
    my %expected_response = $schema->resultset('Track')->find($id)->get_columns;
    my $response = JSON::Any->Load( $mech->content);
    is_deeply( $response, { data => \%expected_response, success => 'true' }, 'correct data returned for track with datetime' );
}

done_testing();
