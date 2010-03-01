package Catalyst::Controller::DBIC::API::Request;

#ABSTRACT: Provides a role to be applied to the Request object
use Moose::Role;
use MooseX::Types::Moose(':all');
use namespace::autoclean;

#XXX HACK
sub _application {}
sub _controller {}

=attribute_private _application is: ro, isa: Object, handles: Catalyst::Controller::DBIC::API::StoredResultSource

This attribute helps bridge between the request guts and the application guts; allows request argument validation against the schema. This is set during L<Catalyst::Controller::DBIC::API/inflate_request>

=cut

has '_application' =>
(
    is => 'ro',
    writer => '_set_application',
    isa => Object|ClassName,
);

has '_controller' =>
(
    is => 'ro',
    writer => '_set_controller',
    isa => Object,
    trigger => sub
    {
        my ($self, $new) = @_;

        $self->_set_class($new->class) if defined($new->class);
        $self->_set_application($new->_application);
        $self->_set_prefetch_allows($new->prefetch_allows);
        $self->_set_search_exposes($new->search_exposes);
        $self->_set_select_exposes($new->select_exposes);
    }
);

with 'Catalyst::Controller::DBIC::API::StoredResultSource';
with 'Catalyst::Controller::DBIC::API::RequestArguments';
with 'Catalyst::Controller::DBIC::API::Request::Context';

=head1 DESCRIPTION

Please see L<Catalyst::Controller::DBIC::API::RequestArguments> and L<Catalyst::Controller::DBIC::API::Request::Context> for the details of this class, as both of those roles are consumed in this role.

=cut

1;
