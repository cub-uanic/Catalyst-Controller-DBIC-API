package Catalyst::Controller::DBIC::API::REST;

#ABSTRACT: Provides a REST interface to DBIx::Class
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API'; }

__PACKAGE__->config(
    'default'   => 'application/json',
    'stash_key' => 'response',
    'map'       => {
        'application/x-www-form-urlencoded' => 'JSON',
        'application/json'                  => 'JSON',
    });

=head1 DESCRIPTION

Provides a REST style API interface to the functionality described in L<Catalyst::Controller::DBIC::API>. 

By default provides the following endpoints:

  $base (accepts PUT and GET)
  $base/[identifier] (accepts POST and DELETE)

Where $base is the URI described by L</setup>, the chain root of the controller, and the request type will determine the L<Catalyst::Controller::DBIC::API> method to forward.

=method_protected setup

Chained: override
PathPart: override
CaptureArgs: 0

As described in L<Catalyst::Controller::DBIC::API/setup>, this action is the chain root of the controller but has no pathpart or chain parent defined by default, so these must be defined in order for the controller to function. The neatest way is normally to define these using the controller's config.

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'track', Chained => '/api/rest/rest_base' } }, 
	...
  );

=method_protected base

Chained: L</setup>
PathPart: none
CaptureArgs: 0

Forwards to list level methods described in L<Catalyst::Controller::DBIC::API> as follows:

DELETE: forwards to L<Catalyst::Controller::DBIC::API/object> then L<Catalyst::Controller::DBIC::API/delete>
POST/PUT: forwards to L<Catalyst::Controller::DBIC::API/object> then L<Catalyst::Controller::DBIC::API/update_or_create>
GET: forwards to L<Catalyst::Controller::DBIC::API/list>

=cut

sub no_id : Chained('object_no_id') PathPart('') ActionClass('REST') :CaptureArgs(0) {}

sub no_id_PUT
{
	my ( $self, $c ) = @_;
    $c->forward('update_or_create');
}

sub no_id_POST
{
	my ( $self, $c ) = @_;
    $c->forward('update_or_create');
}

sub no_id_DELETE
{
	my ( $self, $c ) = @_;
    $c->forward('delete');
}

sub no_id_GET
{
	my ( $self, $c ) = @_;
	$c->forward('list');
}

sub with_id :Chained('object_with_id') :PathPart('') :ActionClass('REST') :CaptureArgs(0) {}

sub with_id_PUT
{
	my ( $self, $c ) = @_;
    $c->forward('update_or_create');
}

sub with_id_POST
{
	my ( $self, $c ) = @_;
    $c->forward('update_or_create');
}

sub with_id_DELETE
{
	my ( $self, $c ) = @_;
    $c->forward('delete');
}

sub with_id_GET
{
	my ( $self, $c ) = @_;
	$c->forward('item');
}

1;
