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

  $base (operates on lists of objects and accepts GET, PUT, POST and DELETE)
  $base/[identifier] (operates on a single object and accepts GET, PUT, POST and DELETE)

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

=method_protected no_id

Chained: L</objects_no_id>
PathPart: none
CaptureArgs: 0

Calls list level methods described in L<Catalyst::Controller::DBIC::API> as follows:

DELETE: L<Catalyst::Controller::DBIC::API/delete>
POST/PUT: L<Catalyst::Controller::DBIC::API/update_or_create>
GET: forwards to L<Catalyst::Controller::DBIC::API/list>

=cut

sub no_id : Chained('objects_no_id') PathPart('') ActionClass('REST') :Args(0) {}

sub no_id_PUT
{
	my ( $self, $c ) = @_;
    $self->update_or_create($c);
}

sub no_id_POST
{
	my ( $self, $c ) = @_;
    $self->update_or_create($c);
}

sub no_id_DELETE
{
	my ( $self, $c ) = @_;
    $self->delete($c);
}

sub no_id_GET
{
	my ( $self, $c ) = @_;
    $self->list($c);
}

=method_protected with_id

Chained: L</object_with_id>
PathPart: none
CaptureArgs: 0

Forwards to list level methods described in L<Catalyst::Controller::DBIC::API> as follows:

DELETE: L<Catalyst::Controller::DBIC::API/delete>
POST/PUT: L<Catalyst::Controller::DBIC::API/update_or_create>
GET: forwards to L<Catalyst::Controller::DBIC::API/item>

=cut

sub with_id :Chained('object_with_id') :PathPart('') :ActionClass('REST') :Args(0) {}

sub with_id_PUT
{
	my ( $self, $c ) = @_;
    $self->update_or_create($c);
}

sub with_id_POST
{
	my ( $self, $c ) = @_;
    $self->update_or_create($c);
}

sub with_id_DELETE
{
	my ( $self, $c ) = @_;
    $self->delete($c);
}

sub with_id_GET
{
	my ( $self, $c ) = @_;
    $self->item($c);
}

1;
