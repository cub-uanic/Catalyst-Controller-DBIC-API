package Catalyst::Controller::DBIC::API::JoinBuilder;

#ABSTRACT: Provides a helper class to automatically keep track of joins in complex searches
use Moose;
use MooseX::Types::Moose(':all');
use Catalyst::Controller::DBIC::API::Types(':all');
use namespace::autoclean;

=attribute_public parent is: ro, isa: 'Catalyst::Controller::DBIC::API::JoinBuilder'

parent stores the direct ascendant in the datastructure that represents the join

=cut

has parent =>
(
    is => 'ro',
    isa => JoinBuilder,
    predicate => 'has_parent',
    weak_ref => 1,
    trigger => sub { my ($self, $new) = @_; $new->add_child($self); },
);

=attribute_public children is: ro, isa: ArrayRef['Catalyst::Controller::DBIC::API::JoinBuilder'], traits => ['Array']

children stores the immediate descendants in the datastructure that represents the join.

Handles the following methods:

    all_children => 'elements'
    has_children => 'count'
    add_child => 'push'

=cut

has children =>
(
    is => 'ro',
    isa => ArrayRef[JoinBuilder],
    traits => ['Array'],
    default => sub { [] },
    handles =>
    {
        all_children => 'elements',
        has_children => 'count',
        add_child => 'push',
    }
);

=attribute_public joins is: ro, isa: HashRef, lazy_build: true

joins holds the cached generated join datastructure.

=cut

has joins =>
(
    is => 'ro',
    isa => HashRef,
    lazy_build => 1,
);

=attribute_public name is: ro, isa: Str, required: 1

Sets the key for this level in the generated hash

=cut

has name =>
(
    is => 'ro',
    isa => Str,
    required => 1,
);

=method_private _build_joins

_build_joins finds the top parent in the structure and then recursively iterates the children building out the join datastructure

=cut

sub _build_joins
{
    my ($self) = @_;
    
    my $parent;
    while(my $found = $self->parent)
    {
        if($found->has_parent)
        {
            $self = $found;
            next;
        }
        $parent = $found;
    }

    my $builder;
    $builder = sub
    {
        my ($node) = @_;
        my $foo = {};
        map { $foo->{$_->name} = $builder->($_) } $node->all_children;
        return $foo;
    };

    return $builder->($parent || $self);
}

=head1 DESCRIPTION

JoinBuilder is used to keep track of joins automgically for complex searches. It accomplishes this by building a simple tree of parents and children and then recursively drilling into the tree to produce a useable join attribute for ->search.

=cut

1;
