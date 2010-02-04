package Catalyst::Controller::DBIC::API::Types;

#ABSTRACT: Provides shortcut types and coercions for DBIC::API
use warnings;
use strict;

use MooseX::Types -declare => [qw/OrderedBy GroupedBy Prefetch SelectColumns AsAliases ResultSource ResultSet Model SearchParameters JoinBuilder/];
use MooseX::Types::Moose(':all');

=type Prefetch as Maybe[ArrayRef[Str|HashRef]]

Represents the structure of the prefetch argument.

Coerces Str and HashRef.

=cut

subtype Prefetch, as Maybe[ArrayRef[Str|HashRef]];
coerce Prefetch, from Str, via { [$_] }, from HashRef, via { [$_] };

=type GroupedBy as Maybe[ArrayRef[Str]]

Represents the structure of the grouped_by argument.

Coerces Str.

=cut

subtype GroupedBy, as Maybe[ArrayRef[Str]];
coerce GroupedBy, from Str, via { [$_] };

=type OrderedBy as Maybe[ArrayRef[Str|HashRef|ScalarRef]]

Represents the structure of the ordered_by argument

Coerces Str.

=cut

subtype OrderedBy, as Maybe[ArrayRef[Str|HashRef|ScalarRef]];
coerce OrderedBy, from Str, via { [$_] };

=type SelectColumns as Maybe[ArrayRef[Str|HashRef]]

Represents the structure of the select argument

Coerces Str.

=cut

subtype SelectColumns, as Maybe[ArrayRef[Str|HashRef]];
coerce SelectColumns, from Str, via { [$_] };

=type SearchParameters as Maybe[ArrayRef[HashRef]]

Represents the structure of the search argument

Coerces HashRef.

=cut

subtype SearchParameters, as Maybe[ArrayRef[HashRef]];
coerce SearchParameters, from HashRef, via { [$_] };

=type AsAliases as Maybe[ArrayRef[Str]]

Represents the structure of the as argument

=cut

subtype AsAliases, as Maybe[ArrayRef[Str]];

=type ResultSet as class_type('DBIx::Class::ResultSet')

Shortcut for DBIx::Class::ResultSet

=cut

subtype ResultSet, as class_type('DBIx::Class::ResultSet');

=type ResultSource as class_type('DBIx::Class::ResultSource')

Shortcut for DBIx::Class::ResultSource

=cut

subtype ResultSource, as class_type('DBIx::Class::ResultSource');

=type JoinBuilder as class_type('Catalyst::Controller::DBIC::API::JoinBuilder')

Shortcut for Catalyst::Controller::DBIC::API::JoinBuilder

=cut

subtype JoinBuilder, as class_type('Catalyst::Controller::DBIC::API::JoinBuilder');

=type Model as class_type('DBIx::Class')

Shortcut for model objects

=cut

subtype Model, as class_type('DBIx::Class');

1;
