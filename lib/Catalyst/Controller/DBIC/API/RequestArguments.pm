package Catalyst::Controller::DBIC::API::RequestArguments;

#ABSTRACT: Provides Request argument validation
use MooseX::Role::Parameterized;
use Catalyst::Controller::DBIC::API::Types(':all');
use MooseX::Types::Moose(':all');
use Scalar::Util('reftype');
use Data::Dumper;
use namespace::autoclean;

use Catalyst::Controller::DBIC::API::JoinBuilder;

=attribute_private search_validator

A Catalyst::Controller::DBIC::API::Validator instance used solely to validate search parameters

=cut

with 'MooseX::Role::BuildInstanceOf' =>
{
    'target' => 'Catalyst::Controller::DBIC::API::Validator',
    'prefix' => 'search_validator',
};

=attribute_private select_validator

A Catalyst::Controller::DBIC::API::Validator instance used solely to validate select parameters

=cut

with 'MooseX::Role::BuildInstanceOf' =>
{
    'target' => 'Catalyst::Controller::DBIC::API::Validator',
    'prefix' => 'select_validator',
};

=attribute_private prefetch_validator

A Catalyst::Controller::DBIC::API::Validator instance used solely to validate prefetch parameters

=cut

with 'MooseX::Role::BuildInstanceOf' =>
{
    'target' => 'Catalyst::Controller::DBIC::API::Validator',
    'prefix' => 'prefetch_validator',
};

parameter static => ( isa => Bool, default => 0 );

role {

    my $p = shift;

    if($p->static)
    {
        requires qw/check_has_relation check_column_relation/;
    }
    else
    {
        requires qw/_controller check_has_relation check_column_relation/;
    }

=attribute_public count is: ro, isa: Int

count is the number of rows to be returned during paging

=cut

    has 'count' =>
    (
        is => 'ro',
        writer => '_set_count',
        isa => Int,
        predicate => 'has_count',
    );

=attribute_public page is: ro, isa: Int

page is what page to return while paging

=cut

    has 'page' =>
    (
        is => 'ro',
        writer => '_set_page',
        isa => Int,
        predicate => 'has_page',
    );

=attribute_public offset is ro, isa: Int

offset specifies where to start the paged result (think SQL LIMIT)

=cut

    has 'offset' =>
    (
        is => 'ro',
        writer => '_set_offset',
        isa => Int,
        predicate => 'has_offset',
    );

=attribute_public ordered_by is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/OrderedBy>

ordered_by is passed to ->search to determine sorting

=cut

    has 'ordered_by' =>
    (
        is => 'ro',
        writer => '_set_ordered_by',
        isa => OrderedBy,
        predicate => 'has_ordered_by',
        coerce => 1,
        default => sub { $p->static ? [] : undef },
    );

=attribute_public groupd_by is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/GroupedBy>

grouped_by is passed to ->search to determine aggregate results

=cut

    has 'grouped_by' =>
    (
        is => 'ro',
        writer => '_set_grouped_by',
        isa => GroupedBy,
        predicate => 'has_grouped_by',
        coerce => 1,
        default => sub { $p->static ? [] : undef },
    );

=attribute_public prefetch is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/Prefetch>

prefetch is passed to ->search to optimize the number of database fetches for joins

=cut

    has prefetch =>
    (
        is => 'ro',
        writer => '_set_prefetch',
        isa => Prefetch,
        default => sub { $p->static ? [] : undef },
        coerce => 1,
        trigger => sub
        {
            my ($self, $new) = @_;
            if($self->has_prefetch_allows and @{$self->prefetch_allows})
            {
                foreach my $pf (@$new)
                {
                    if(HashRef->check($pf))
                    {
                        die qq|'${\Dumper($pf)}' is not an allowed prefetch in: ${\join("\n", @{$self->prefetch_validator->templates})}|
                            unless $self->prefetch_validator->validate($pf)->[0];
                    }
                    else
                    {
                        die qq|'$pf' is not an allowed prefetch in: ${\join("\n", @{$self->prefetch_validator->templates})}|
                            unless $self->prefetch_validator->validate({$pf => 1})->[0];
                    }
                }
            }
            else
            {
                return if not defined($new);
                die 'Prefetching is not allowed' if @$new;
            }
        },
    );

=attribute_public prefetch_allows is: ro, isa: ArrayRef[ArrayRef|Str|HashRef]

prefetch_allows limits what relations may be prefetched when executing searches with joins. This is necessary to avoid denial of service attacks in form of queries which would return a large number of data and unwanted disclosure of data.

Like the synopsis in DBIC::API shows, you can declare a "template" of what is allowed (by using an '*'). Each element passed in, will be converted into a Data::DPath and added to the validator.

    prefetch_allows => [ 'cds', { cds => tracks }, { cds => producers } ] # to be explicit
    prefetch_allows => [ 'cds', { cds => '*' } ] # wildcard means the same thing

=cut

    has prefetch_allows =>
    (
        is => 'ro',
        writer => '_set_prefetch_allows',
        isa => ArrayRef[ArrayRef|Str|HashRef],
        default => sub { [ ] },
        predicate => 'has_prefetch_allows',
        trigger => sub
        {
            my ($self, $new) = @_;

            sub _check_rel {
                my ($self, $rel, $static) = @_;
                if(ArrayRef->check($rel))
                {
                    foreach my $rel_sub (@$rel)
                    {
                        $self->_check_rel($rel_sub, $static);
                    }
                }
                elsif(HashRef->check($rel))
                {
                    while(my($k,$v) = each %$rel)
                    {
                        $self->check_has_relation($k, $v, undef, $static);
                    }
                    $self->prefetch_validator->load($rel);
                }
                else
                {
                    $self->check_has_relation($rel, undef, undef, $static);
                    $self->prefetch_validator->load($rel);
                }
            }

            foreach my $rel (@$new)
            {
                $self->_check_rel($rel, $p->static);
            }
        },
    );

=attribute_public search_exposes is: ro, isa: ArrayRef[Str|HashRef]

search_exposes limits what can actually be searched. If a certain column isn't indexed or perhaps a BLOB, you can explicitly say which columns can be search and exclude that one.

Like the synopsis in DBIC::API shows, you can declare a "template" of what is allowed (by using an '*'). Each element passed in, will be converted into a Data::DPath and added to the validator.

=cut

    has 'search_exposes' =>
    (
        is => 'ro',
        writer => '_set_search_exposes',
        isa => ArrayRef[Str|HashRef],
        predicate => 'has_search_exposes',
        default => sub { [ ] },
        trigger => sub
        {
            my ($self, $new) = @_;
            $self->search_validator->load($_) for @$new;
        },
    );

=attribute_public search is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/SearchParameters>

search contains the raw search parameters. Upon setting, a trigger will fire to format them, set search_parameters, and set search_attributes.

Please see L</generate_parameters_attributes> for details on how the format works.

=cut

    has 'search' =>
    (
        is => 'ro',
        writer => '_set_search',
        isa => SearchParameters,
        predicate => 'has_search',
        coerce => 1,
        trigger => sub
        {
            my ($self, $new) = @_;

            if($self->has_search_exposes and @{$self->search_exposes})
            {
                foreach my $foo (@$new)
                {
                    while( my ($k, $v) = each %$foo)
                    {
                        local $Data::Dumper::Terse = 1;
                        die qq|{ $k => ${\Dumper($v)} } is not an allowed search term in: ${\join("\n", @{$self->search_validator->templates})}|
                            unless $self->search_validator->validate({$k=>$v})->[0];
                    }
                }
            }
            else
            {
                foreach my $foo (@$new)
                {
                    while( my ($k, $v) = each %$foo)
                    {
                        $self->check_column_relation({$k => $v});
                    }
                }
            }

            my ($search_parameters, $search_attributes) = $self->generate_parameters_attributes($new);
            $self->_set_search_parameters($search_parameters);
            $self->_set_search_attributes($search_attributes);

        },
    );

=attribute_public search_parameters is:ro, isa: L<Catalyst::Controller::DBIC::API::Types/SearchParameters>

search_parameters stores the formatted search parameters that will be passed to ->search

=cut

    has search_parameters =>
    (
        is => 'ro',
        isa => SearchParameters,
        writer => '_set_search_parameters',
        predicate => 'has_search_parameters',
        coerce => 1,
        default => sub { [{}] },
    );

=attribute_public search_attributes is:ro, isa: HashRef

search_attributes stores the formatted search attributes that will be passed to ->search

=cut

    has search_attributes =>
    (
        is => 'ro',
        isa => HashRef,
        writer => '_set_search_attributes',
        predicate => 'has_search_attributes',
        lazy_build => 1,
    );

=attribute_public search_total_entries is: ro, isa: Int

search_total_entries stores the total number of entries in a paged search result

=cut

    has search_total_entries =>
    (
        is => 'ro',
        isa => Int,
        writer => '_set_search_total_entries',
        predicate => 'has_search_total_entries',
    );

=attribute_public select_exposes is: ro, isa: ArrayRef[Str|HashRef]

select_exposes limits what can actually be selected. Use this to whitelist database functions (such as COUNT).

Like the synopsis in DBIC::API shows, you can declare a "template" of what is allowed (by using an '*'). Each element passed in, will be converted into a Data::DPath and added to the validator.

=cut

    has 'select_exposes' =>
    (
        is => 'ro',
        writer => '_set_select_exposes',
        isa => ArrayRef[Str|HashRef],
        predicate => 'has_select_exposes',
        default => sub { [ ] },
        trigger => sub
        {
            my ($self, $new) = @_;
            $self->select_validator->load($_) for @$new;
        },
    );

=attribute_public select is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/SelectColumns>

select is the search attribute that allows you to both limit what is returned in the result set, and also make use of database functions like COUNT.

Please see L<DBIx::Class::ResultSet/select> for more details.

=cut

    has select =>
    (
        is => 'ro',
        writer => '_set_select',
        isa => SelectColumns,
        predicate => 'has_select',
        default => sub { $p->static ? [] : undef },
        coerce => 1,
        trigger => sub
        {
            my ($self, $new) = @_;
            if($self->has_select_exposes)
            {
                foreach my $val (@$new)
                {
                    die "'$val' is not allowed in a select"
                        unless $self->select_validator->validate($val);
                }
            }
            else
            {
                $self->check_column_relation($_, $p->static) for @$new;
            }
        },
    );

=attribute_public as is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/AsAliases>

as is the search attribute compliment to L</select> that allows you to label columns for object inflaction and actually reference database functions like COUNT.

Please see L<DBIx::Class::ResultSet/as> for more details.

=cut

    has as =>
    (
        is => 'ro',
        writer => '_set_as',
        isa => AsAliases,
        default => sub { $p->static ? [] : undef },
        trigger => sub
        {
            my ($self, $new) = @_;
            if($self->has_select)
            {
                die "'as' argument count (${\scalar(@$new)}) must match 'select' argument count (${\scalar(@{$self->select || []})})"
                    unless @$new == @{$self->select || []};
            }
            elsif(defined $new)
            {
                die "'as' is only valid if 'select is also provided'";
            }
        }
    );

=attribute_public joins is: ro, isa L<Catalyst::Controller::DBIC::API::Types/JoinBuilder>

joins holds the top level JoinBuilder object used to keep track of joins automagically while formatting complex search parameters.

Provides a single handle which returns the 'join' attribute for search_attributes:

    build_joins => 'joins'

=cut

    has joins =>
    (
        is => 'ro',
        isa => JoinBuilder,
        lazy_build => 1,
        handles =>
        {
            build_joins => 'joins',
        }
    );

=attribute_public request_data is: ro, isa: HashRef

request_data holds the raw (but deserialized) data for ths request

=cut

    has 'request_data' =>
    (
        is => 'ro',
        isa => HashRef,
        writer => '_set_request_data',
        predicate => 'has_request_data',
        trigger => sub
        {
            my ($self, $new) = @_;
            my $controller = $self->_controller;
            return unless defined($new) && keys %$new;
            $self->_set_prefetch($new->{$controller->prefetch_arg}) if exists $new->{$controller->prefetch_arg};
            $self->_set_select($new->{$controller->select_arg}) if exists $new->{$controller->select_arg};
            $self->_set_as($new->{$controller->as_arg}) if exists $new->{$controller->as_arg};
            $self->_set_grouped_by($new->{$controller->grouped_by_arg}) if exists $new->{$controller->grouped_by_arg};
            $self->_set_ordered_by($new->{$controller->ordered_by_arg}) if exists $new->{$controller->ordered_by_arg};
            $self->_set_count($new->{$controller->count_arg}) if exists $new->{$controller->count_arg};
            $self->_set_page($new->{$controller->page_arg}) if exists $new->{$controller->page_arg};
            $self->_set_offset($new->{$controller->offset_arg}) if exists $new->{$controller->offset_arg};
            $self->_set_search($new->{$controller->search_arg}) if exists $new->{$controller->search_arg};
        }
    );

    method _build_joins => sub { return Catalyst::Controller::DBIC::API::JoinBuilder->new(name => 'TOP') };

=method_protected format_search_parameters

format_search_parameters iterates through the provided params ArrayRef, calling generate_column_parameters on each one

=cut

    method format_search_parameters => sub
    {
        my ($self, $params) = @_;

        my $genparams = [];

        foreach my $param (@$params)
        {
            push(@$genparams, $self->generate_column_parameters($self->stored_result_source, $param, $self->joins));
        }

        return $genparams;
    };

=method_protected generate_column_parameters

generate_column_parameters recursively generates properly aliased parameters for search, building a new JoinBuilder each layer of recursion

=cut

    method generate_column_parameters => sub
    {
        my ($self, $source, $param, $join, $base) = @_;
        $base ||= 'me';
        my $search_params = {};

        # build up condition
        foreach my $column (keys %$param)
        {
            if($source->has_relationship($column))
            {
                unless (ref($param->{$column}) && reftype($param->{$column}) eq 'HASH')
                {
                    $search_params->{join('.', $base, $column)} = $param->{$column};
                    next;
                }

                $search_params = { %$search_params, %{
                    $self->generate_column_parameters
                    (
                        $source->related_source($column),
                        $param->{$column},
                        Catalyst::Controller::DBIC::API::JoinBuilder->new(parent => $join, name => $column),
                        $column
                    )
                }};
            }
            else
            {
                $search_params->{join('.', $base, $column)} = $param->{$column};
            }
        }

        return $search_params;
    };

=method_protected generate_parameters_attributes

generate_parameters_attributes takes the raw search arguments and formats the parameters by calling format_search_parameters. Then builds the related attributes, preferring request-provided arguments for things like grouped_by over statically configured options. Finally tacking on the appropriate joins. Returns both formatted search parameters and the search attributes.

=cut

    method generate_parameters_attributes => sub
    {
        my ($self, $args) = @_;

        return ( $self->format_search_parameters($args), $self->search_attributes );
    };

=method_protected _build_search_attributes

This builder method generates the search attributes

=cut

    method _build_search_attributes => sub
    {
        my ($self, $args) = @_;
        my $static = $self->_controller;
        my $search_attributes =
        {
            group_by => $self->grouped_by || ((scalar(@{$static->grouped_by})) ? $static->grouped_by : undef),
            order_by => $self->ordered_by || ((scalar(@{$static->ordered_by})) ? $static->ordered_by : undef),
            select => $self->select || ((scalar(@{$static->select})) ? $static->select : undef),
            as => $self->as || ((scalar(@{$static->as})) ? $static->as : undef),
            prefetch => $self->prefetch || $static->prefetch || undef,
            rows => $self->count || $static->count,
            page => $static->page,
            offset => $self->offset,
            join => $self->build_joins,
        };

        if($self->has_page)
        {
            $search_attributes->{page} = $self->page;
        }
        elsif(!$self->has_page && defined($search_attributes->{offset}) && defined($search_attributes->{rows}))
        {
            $search_attributes->{page} = $search_attributes->{offset} / $search_attributes->{rows} + 1;
            delete $search_attributes->{offset};
        }


        $search_attributes =
        {
            map { @$_ }
            grep
            {
                defined($_->[1])
                ?
                    (ref($_->[1]) && reftype($_->[1]) eq 'HASH' && keys %{$_->[1]})
                    || (ref($_->[1]) && reftype($_->[1]) eq 'ARRAY' && @{$_->[1]})
                    || length($_->[1])
                :
                    undef
            }
            map { [$_, $search_attributes->{$_}] }
            keys %$search_attributes
        };


        if ($search_attributes->{page} && !$search_attributes->{rows}) {
            die 'list_page can only be used with list_count';
        }

        if ($search_attributes->{select}) {
            # make sure all columns have an alias to avoid ambiguous issues
            # but allow non strings (eg. hashrefs for db procs like 'count')
            # to pass through unmolested
            $search_attributes->{select} = [map { (Str->check($_) && $_ !~ m/\./) ? "me.$_" : $_ } (ref $search_attributes->{select}) ? @{$search_attributes->{select}} : $search_attributes->{select}];
        }

        return $search_attributes;

    };

};
=head1 DESCRIPTION

RequestArguments embodies those arguments that are provided as part of a request or effect validation on request arguments. This Role can be consumed in one of two ways. As this is a parameterized Role, it accepts a single argument at composition time: 'static'. This indicates that those parameters should be stored statically and used as a fallback when the current request doesn't provide them.

=cut


1;
