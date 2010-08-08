package Catalyst::Controller::DBIC::API::RPC;
#ABSTRACT: Provides an RPC interface to DBIx::Class

use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API'; }

__PACKAGE__->config(
    'action'    => { object_with_id => { PathPart => 'id' } },
    'default'   => 'application/json',
    'stash_key' => 'response',
    'map'       => {
        'application/x-www-form-urlencoded' => 'JSON',
        'application/json'                  => 'JSON',
    },
);

=head1 DESCRIPTION

Provides an RPC API interface to the functionality described in L<Catalyst::Controller::DBIC::API>.

By default provides the following endpoints:

  $base/create
  $base/list
  $base/id/[identifier]
  $base/id/[identifier]/delete
  $base/id/[identifier]/update

Where $base is the URI described by L</setup>, the chain root of the controller.

=method_protected setup

Chained: override
PathPart: override
CaptureArgs: 0

As described in L<Catalyst::Controller::DBIC::API/setup>, this action is the chain root of the controller but has no pathpart or chain parent defined by default, so these must be defined in order for the controller to function. The neatest way is normally to define these using the controller's config.

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'track', Chained => '/api/rpc/rpc_base' } },
	...
  );

=cut

=method_protected create

Chained: L</objects_no_id>
PathPart: create
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/update_or_create>.

=cut

sub create :Chained('objects_no_id') :PathPart('create') :Args(0)
{
	my ($self, $c) = @_;
    $self->update_or_create($c);
}

=method_protected list

Chained: L</deserialize>
PathPart: list
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/list>.

=cut

sub list :Chained('deserialize') :PathPart('list') :Args(0)
{
	my ($self, $c) = @_;
    $self->next::method($c);
}

=method_protected item

Chained: L</object_with_id>
PathPart: ''
Args: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/item>.

=cut

sub item :Chained('object_with_id') :PathPart('') :Args(0)
{
    my ($self, $c) = @_;
    $self->next::method($c);
}

=method_protected update

Chained: L</object_with_id>
PathPart: update
Args: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/update_or_create>.

=cut

sub update :Chained('object_with_id') :PathPart('update') :Args(0)
{
    my ($self, $c) = @_;
    $self->update_or_create($c);
}

=method_protected delete

Chained: L</object_with_id>
PathPart: delete
Args: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/delete>.

=cut

sub delete :Chained('object_with_id') :PathPart('delete') :Args(0)
{
    my ($self, $c) = @_;
    $self->next::method($c);
}

=method_protected update_bulk

Chained: L</objects_no_id>
PathPart: update
Args: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/update_or_create> for multiple objects.

=cut

sub update_bulk :Chained('objects_no_id') :PathPart('update') :Args(0)
{
    my ($self, $c) = @_;
    $self->update_or_create($c);
}

=method_protected delete_bulk

Chained: L</objects_no_id>
PathPart: delete
Args: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/delete> for multiple objects.

=cut

sub delete_bulk :Chained('objects_no_id') :PathPart('delete') :Args(0)
{
    my ($self, $c) = @_;
    $self->delete($c);
}

1;
