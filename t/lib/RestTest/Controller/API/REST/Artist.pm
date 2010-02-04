package RestTest::Controller::API::REST::Artist;
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API::REST' }
use namespace::autoclean;

__PACKAGE__->config
    ( action => { setup => { PathPart => 'artist', Chained => '/api/rest/rest_base' } },
      class => 'RestTestDB::Artist',
      create_requires => ['name'],
      create_allows => ['name'],
      update_allows => ['name'],
      prefetch_allows => [[qw/ cds /],{ 'cds' => 'tracks'}],
      );

1;
