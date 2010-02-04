package Catalyst::Controller::DBIC::API::RPC;
#ABSTRACT: Provides an RPC interface to DBIx::Class

use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API'; }

__PACKAGE__->config(
    'action'    => { object => { PathPart => 'id' } }, 
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

=method_protected object

Chained: L</setup>
PathPart: object
CaptureArgs: 1

Provides an chain point to the functionality described in L<Catalyst::Controller::DBIC::API/object>. All object level endpoints should use this as their chain root.

=cut

sub index : Chained('setup') PathPart('') Args(0) {
	my ( $self, $c ) = @_;

	$self->push_error($c, { message => 'Not implemented' });
	$c->res->status( '404' );
}

=method_protected create

Chained: L</setup>
PathPart: create
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/update_or_create>.

=cut

sub create :Chained('setup') :PathPart('create') :Args(0)
{
	my ($self, $c) = @_;
    $c->forward('object');
    return if $self->get_errors($c);
    $c->forward('update_or_create');
}

=method_protected list

Chained: L</setup>
PathPart: list
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/list>.

=cut

sub list :Chained('setup') :PathPart('list') :Args(0) {
	my ($self, $c) = @_;

        $self->next::method($c);
}

=method_protected update

Chained: L</object>
PathPart: update
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/update_or_create>.

=cut

sub update :Chained('object') :PathPart('update') :Args(0) {
	my ($self, $c) = @_;

    $c->forward('update_or_create');
}

=method_protected delete

Chained: L</object>
PathPart: delete
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/delete>.

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) {
	my ($self, $c) = @_;

        $self->next::method($c);
}

1;
