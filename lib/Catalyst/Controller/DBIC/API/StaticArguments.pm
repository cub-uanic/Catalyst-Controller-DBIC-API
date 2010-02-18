package Catalyst::Controller::DBIC::API::StaticArguments;

#ABSTRACT: Provides controller level configuration arguments
use Moose::Role;
use MooseX::Types::Moose(':all');
use namespace::autoclean;

requires 'check_column_relation';

=attribute_public create_requires create_allows update_requires update_allows

These attributes control requirements and limits to columns when creating or updating objects.

Each provides a number of handles:

    "get_${var}_column" => 'get'
    "set_${var}_column" => 'set'
    "delete_${var}_column" => 'delete'
    "insert_${var}_column" => 'insert'
    "count_${var}_column" => 'count'
    "all_${var}_columns" => 'elements'

=cut

foreach my $var (qw/create_requires create_allows update_requires update_allows/)
{
    has $var =>
    (
        is => 'ro',
        isa => ArrayRef[Str|HashRef],
        traits => ['Array'],
        default => sub { [] },
        trigger => sub
        {   
            my ($self, $new) = @_;
            $self->check_column_relation($_, 1) for @$new;
        },
        handles =>
        {
            "get_${var}_column" => 'get',
            "set_${var}_column" => 'set',
            "delete_${var}_column" => 'delete',
            "insert_${var}_column" => 'insert',
            "count_${var}_column" => 'count',
            "all_${var}_columns" => 'elements',
        }
    );

    before "set_${var}_column" => sub { $_[0]->check_column_relation($_[2], 1) }; #"
    before "insert_${var}_column" => sub { $_[0]->check_column_relation($_[2], 1) }; #"
}

=attribute_public count_arg is: ro, isa: Str, default: 'list_count'

count_arg controls how to reference 'count' in the the request_data

=cut

has 'count_arg' => ( is => 'ro', isa => Str, default => 'list_count' );

=attribute_public page_arg is: ro, isa: Str, default: 'list_page'

page_arg controls how to reference 'page' in the the request_data

=cut

has 'page_arg' => ( is => 'ro', isa => Str, default => 'list_page' );

=attribute_public offset_arg is: ro, isa: Str, default: 'offset'

offset_arg controls how to reference 'offset' in the the request_data

=cut

has 'offset_arg' => ( is => 'ro', isa => Str, default => 'list_offset' );

=attribute_public select_arg is: ro, isa: Str, default: 'list_returns'

select_arg controls how to reference 'select' in the the request_data

=cut

has 'select_arg' => ( is => 'ro', isa => Str, default => 'list_returns' );

=attribute_public as_arg is: ro, isa: Str, default: 'as'

as_arg controls how to reference 'as' in the the request_data

=cut

has 'as_arg' => ( is => 'ro', isa => Str, default => 'as' );

=attribute_public search_arg is: ro, isa: Str, default: 'search'

search_arg controls how to reference 'search' in the the request_data

=cut

has 'search_arg' => ( is => 'ro', isa => Str, default => 'search' );

=attribute_public grouped_by_arg is: ro, isa: Str, default: 'list_grouped_by'

grouped_by_arg controls how to reference 'grouped_by' in the the request_data

=cut

has 'grouped_by_arg' => ( is => 'ro', isa => Str, default => 'list_grouped_by' );

=attribute_public ordered_by_arg is: ro, isa: Str, default: 'list_ordered_by'

ordered_by_arg controls how to reference 'ordered_by' in the the request_data

=cut

has 'ordered_by_arg' => ( is => 'ro', isa => Str, default => 'list_ordered_by' );

=attribute_public prefetch_arg is: ro, isa: Str, default: 'list_prefetch'

prefetch_arg controls how to reference 'prefetch' in the the request_data

=cut

has 'prefetch_arg' => ( is => 'ro', isa => Str, default => 'list_prefetch' );

=attribute_public data_root is: ro, isa: Str, default: 'list'

data_root controls how to reference where the data is in the the request_data

=cut

has 'data_root' => ( is => 'ro', isa => Str, default => 'list');

=attribute_public total_entries_arg is: ro, isa: Str, default: 'totalcount'

total_entries_arg controls how to reference 'total_entries' in the the request_data

=cut

has 'total_entries_arg' => ( is => 'ro', isa => Str, default => 'totalcount' );

=attribute_public use_json_boolean is: ro, isa: Bool, default: 0

use_json_boolean controls whether JSON::Any boolean types are used in the success parameter of the response or if raw strings are used

=cut

has 'use_json_boolean' => ( is => 'ro', isa => Bool, default => 0 );

=attribute_public return_object is: ro, isa: Bool, default: 0

return_object controls whether the results of create/update are serialized and returned in the response

=cut

has 'return_object' => ( is => 'ro', isa => Bool, default => 0 );

=head1 DESCRIPTION

StaticArguments is a Role that is composed by the controller to provide configuration parameters such as how where in the request data to find specific elements, and if to use JSON boolean types.

=cut

1;
