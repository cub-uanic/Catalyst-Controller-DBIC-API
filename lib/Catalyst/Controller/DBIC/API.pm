package Catalyst::Controller::DBIC::API;

#ABSTRACT: Provides a DBIx::Class web service automagically
use Moose;
BEGIN { extends 'Catalyst::Controller::ActionRole'; }

use CGI::Expand ();
use DBIx::Class::ResultClass::HashRefInflator;
use JSON::Any;
use Test::Deep::NoTest('eq_deeply');
use MooseX::Types::Moose(':all');
use Moose::Util;
use Scalar::Util('blessed', 'reftype');
use Try::Tiny;
use Catalyst::Controller::DBIC::API::Request;
use namespace::autoclean;

with 'Catalyst::Controller::DBIC::API::StoredResultSource';
with 'Catalyst::Controller::DBIC::API::StaticArguments';
with 'Catalyst::Controller::DBIC::API::RequestArguments' => { static => 1 };

__PACKAGE__->config();

=head1 SYNOPSIS

  package MyApp::Controller::API::RPC::Artist;
  use Moose;
  BEGIN { extends 'Catalyst::Controller::DBIC::API::RPC' }

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'artist', Chained => '/api/rpc/rpc_base' } }, # define parent chain action and partpath
      class => 'MyAppDB::Artist', # DBIC schema class
      create_requires => ['name', 'age'], # columns required to create
      create_allows => ['nickname'], # additional non-required columns that create allows
      update_allows => ['name', 'age', 'nickname'], # columns that update allows
      update_allows => ['name', 'age', 'nickname'], # columns that update allows
      select => [qw/name age/], # columns that data returns
      prefetch => ['cds'], # relationships that are prefetched when no prefetch param is passed
      prefetch_allows => [ # every possible prefetch param allowed
          'cds',
          qw/ cds /,
          { cds => 'tracks' },
          { cds => [qw/ tracks /] }
      ],
      ordered_by => [qw/age/], # order of generated list
      search_exposes => [qw/age nickname/, { cds => [qw/title year/] }], # columns that can be searched on via list
      data_root => 'data' # defaults to "list" for backwards compatibility
      use_json_boolean => 1, # use JSON::Any::true|false in the response instead of strings
      return_object => 1, # makes create and update actions return the object
      );

  # Provides the following functional endpoints:
  # /api/rpc/artist/create
  # /api/rpc/artist/list
  # /api/rpc/artist/id/[id]/delete
  # /api/rpc/artist/id/[id]/update
=cut

=method_private begin

 :Private

begin is provided in the base class to setup the Catalyst Request object, by applying the DBIC::API::Request role.

=cut

sub begin :Private
{
    my ($self, $c) = @_;

    Catalyst::Controller::DBIC::API::Request->meta->apply($c->req)
        unless Moose::Util::does_role($c->req, 'Catalyst::Controller::DBIC::API::Request');
}

=method_protected setup

 :Chained('specify.in.subclass.config') :CaptureArgs(0) :PathPart('specify.in.subclass.config')

This action is the chain root of the controller. It must either be overridden or configured to provide a base pathpart to the action and also a parent action. For example, for class MyAppDB::Track you might have

  package MyApp::Controller::API::RPC::Track;
  use Moose;
  BEGIN { extends 'Catalyst::Controller::DBIC::API::RPC'; }

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'track', Chained => '/api/rpc/rpc_base' } },
	...
  );

  # or

  sub setup :Chained('/api/rpc_base') :CaptureArgs(0) :PathPart('track') {
    my ($self, $c) = @_;

    $self->next::method($c);
  }

This action does nothing by default.

=cut

sub setup :Chained('specify.in.subclass.config') :CaptureArgs(0) :PathPart('specify.in.subclass.config') {}

=method_protected deserialize

 :Chained('setup') :CaptureArgs(0) :PathPart('') :ActionClass('Deserialize')

deserialize absorbs the request data and transforms it into useful bits by using CGI::Expand->expand_hash and a smattering of JSON::Any->from_json for a handful of arguments. Current only the following arguments are capable of being expressed as JSON:

    search_arg
    count_arg
    page_arg
    ordered_by_arg
    grouped_by_arg
    prefetch_arg

It should be noted that arguments can used mixed modes in with some caveats. Each top level arg can be expressed as CGI::Expand with their immediate child keys expressed as JSON when sending the data application/x-www-form-urlencoded. Otherwise, you can send content as raw json and it will be deserialized as is with no CGI::Expand expasion.

=cut

sub deserialize :Chained('setup') :CaptureArgs(0) :PathPart('') :ActionClass('Deserialize')
{
    my ($self, $c) = @_;
    my $req_params;

    if ($c->req->data && scalar(keys %{$c->req->data}))
    {
        $req_params = $c->req->data;
    }
    else
    {
        $req_params = CGI::Expand->expand_hash($c->req->params);

        foreach my $param (@{[$self->search_arg, $self->count_arg, $self->page_arg, $self->offset_arg, $self->ordered_by_arg, $self->grouped_by_arg, $self->prefetch_arg]})
        {
            # these params can also be composed of JSON
            # but skip if the parameter is not provided
            next if not exists $req_params->{$param};
            # find out if CGI::Expand was involved
            if (ref $req_params->{$param} eq 'HASH')
            {
                for my $key ( keys %{$req_params->{$param}} )
                {
                    try
                    {
                        my $deserialized = JSON::Any->from_json($req_params->{$param}->{$key});
                        $req_params->{$param}->{$key} = $deserialized;
                    }
                    catch
                    {
                        $c->log->debug("Param '$param.$key' did not deserialize appropriately: $_")
                        if $c->debug;
                    }
                }
            }
            else
            {
                try
                {
                    my $deserialized = JSON::Any->from_json($req_params->{$param});
                    $req_params->{$param} = $deserialized;
                }
                catch
                {
                    $c->log->debug("Param '$param' did not deserialize appropriately: $_")
                    if $c->debug;
                }
            }
        }
    }

    $self->inflate_request($c, $req_params);
}

=method_protected generate_rs

generate_rs is used by inflate_request to generate the resultset stored in the current request. It receives $c as its only argument. And by default it merely returns the resultset from the stored_result_source on the controller. Override this method if you need to manipulate the default implementation of getting the resultset from the controller.

=cut

sub generate_rs
{
    my ($self, $c) = @_;
    return $self->stored_result_source->resultset;
}

=method_protected inflate_request

inflate_request is called at the end of deserialize to populate key portions of the request with the useful bits

=cut

sub inflate_request
{
    my ($self, $c, $params) = @_;

    try
    {
        # set static arguments
        $c->req->_set_controller($self);

        # set request arguments
        $c->req->_set_request_data($params);

        # set the current resultset
        $c->req->_set_current_result_set($self->generate_rs($c));

    }
    catch
    {
        $c->log->error($_);
        $self->push_error($c, { message => $_ });
        $c->detach();
    }
}

=method_protected object_with_id

 :Chained('deserialize') :CaptureArgs(1) :PathPart('')

This action is the chain root for all object level actions (such as delete and update) that operate on a single identifer. The provided identifier will be used to find that particular object and add it to the request's store of objects. Please see L<Catalyst::Controller::DBIC::API::Context> for more details on the stored objects.

=cut

sub object_with_id :Chained('deserialize') :CaptureArgs(1) :PathPart('')
{
	my ($self, $c, $id) = @_;

    my $vals = $c->req->request_data->{$self->data_root};
    unless(defined($vals))
    {
        # no data root, assume the request_data itself is the payload
        $vals = $c->req->request_data;
    }

    try
    {
        # there can be only one set of data
        $c->req->add_object([$self->object_lookup($c, $id), $vals]);
    }
    catch
    {
        $c->log->error($_);
        $self->push_error($c, { message => $_ });
        $c->detach();
    }
}

=method_protected objects_no_id

 :Chained('deserialize') :CaptureArgs(0) :PathPart('')

This action is the chain root for object level actions (such as create, update, or delete) that can involve more than one object. The data stored at the data_root of the request_data will be interpreted as an array of hashes on which to operate. If the hashes are missing an 'id' key, they will be considered a new object to be created. Otherwise, the values in the hash will be used to perform an update. As a special case, a single hash sent will be coerced into an array. Please see L<Catalyst::Controller::DBIC::API::Context> for more details on the stored objects.

=cut

sub objects_no_id :Chained('deserialize') :CaptureArgs(0) :PathPart('')
{
    my ($self, $c) = @_;

    if($c->req->has_request_data)
    {
        my $data = $c->req->request_data;
        my $vals;

        if(exists($data->{$self->data_root}) && defined($data->{$self->data_root}))
        {
            my $root = $data->{$self->data_root};
            if(reftype($root) eq 'ARRAY')
            {
                $vals = $root;
            }
            elsif(reftype($root) eq 'HASH')
            {
                $vals = [$root];
            }
            else
            {
                $c->log->error('Invalid request data');
                $self->push_error($c, { message => 'Invalid request data' });
                $c->detach();
            }
        }
        else
        {
            # no data root, assume the request_data itself is the payload
            $vals = [$c->req->request_data];
        }

        foreach my $val (@$vals)
        {
            unless(exists($val->{id}))
            {
                $c->req->add_object([$c->req->current_result_set->new_result({}), $val]);
                next;
            }

            try
            {
                $c->req->add_object([$self->object_lookup($c, $val->{id}), $val]);
            }
            catch
            {
                $c->log->error($_);
                $self->push_error($c, { message => $_ });
                $c->detach();
            }
        }
    }
}

=method_protected object_lookup

This method provides the look up functionality for an object based on 'id'. It is passed the current $c and the $id to be used to perform the lookup. Dies if there is no provided $id or if no object was found.

=cut

sub object_lookup
{
    my ($self, $c, $id) = @_;

    die 'No valid ID provided for look up' unless defined $id and length $id;
    my $object = $c->req->current_result_set->find($id);
    die "No object found for id '$id'" unless defined $object;
    return $object;
}

=method_protected list

list's steps are broken up into three distinct methods: L</list_munge_parameters>, L</list_perform_search>, and L</list_format_output>.

The goal of this method is to call ->search() on the current_result_set, HashRefInflator the result, and return it in $c->stash->{response}->{$self->data_root}. Please see the individual methods for more details on what actual processing takes place.

If the L</select> config param is defined then the hashes will contain only those columns, otherwise all columns in the object will be returned. L</select> of course supports the function/procedure calling semantics that L<DBIx::Class::ResultSet/select>. In order to have proper column names in the result, provide arguments in L</as> (which also follows L<DBIx::Class::ResultSet/as> semantics. Similarly L</count>, L</page>, L</grouped_by> and L</ordered_by> affect the maximum number of rows returned as well as the ordering and grouping. Note that if select, count, ordered_by or grouped_by request parameters are present then these will override the values set on the class with select becoming bound by the select_exposes attribute.

If not all objects in the resultset are required then it's possible to pass conditions to the method as request parameters. You can use a JSON string as the 'search' parameter for maximum flexibility or use L<CGI::Expand> syntax. In the second case the request parameters are expanded into a structure and then used as the search condition.

For example, these request parameters:

 ?search.name=fred&search.cd.artist=luke
 OR
 ?search={"name":"fred","cd": {"artist":"luke"}}

Would result in this search (where 'name' is a column of the schema class, 'cd' is a relation of the schema class and 'artist' is a column of the related class):

 $rs->search({ name => 'fred', 'cd.artist' => 'luke' }, { join => ['cd'] })

It is also possible to use a JSON string for expandeded parameters:

 ?search.datetime={"-between":["2010-01-06 19:28:00","2010-01-07 19:28:00"]}

Note that if pagination is needed, this can be achieved using a combination of the L</count> and L</page> parameters. For example:

  ?page=2&count=20

Would result in this search:

 $rs->search({}, { page => 2, rows => 20 })

=cut

sub list
{
    my ($self, $c) = @_;

    $self->list_munge_parameters($c);
    $self->list_perform_search($c);
    $self->list_format_output($c);

    # make sure there are no objects lingering
    $c->req->clear_objects();
}

=method_protected list_munge_parameters

list_munge_parameters is a noop by default. All arguments will be passed through without any manipulation. In order to successfully manipulate the parameters before the search is performed, simply access $c->req->search_parameters|search_attributes (ArrayRef and HashRef respectively), which correspond directly to ->search($parameters, $attributes). Parameter keys will be in already-aliased form.
To store the munged parameters call $c->req->_set_search_parameters($newparams) and $c->req->_set_search_attributes($newattrs).

=cut

sub list_munge_parameters { } # noop by default

=method_protected list_perform_search

list_perform_search executes the actual search. current_result_set is updated to contain the result returned from ->search. If paging was requested, search_total_entries will be set as well.

=cut

sub list_perform_search
{
    my ($self, $c) = @_;

    try
    {
        my $req = $c->req;

        my $rs = $req->current_result_set->search
        (
            $req->search_parameters,
            $req->search_attributes
        );

        $req->_set_current_result_set($rs);

        $req->_set_search_total_entries($req->current_result_set->pager->total_entries)
            if $req->has_search_attributes && (exists($req->search_attributes->{page}) && defined($req->search_attributes->{page}) && length($req->search_attributes->{page}));
    }
    catch
    {
        $c->log->error($_);
        $self->push_error($c, { message => 'a database error has occured.' });
        $c->detach();
    }
}

=method_protected list_format_output

list_format_output prepares the response for transmission across the wire. A copy of the current_result_set is taken and its result_class is set to L<DBIx::Class::ResultClass::HashRefInflator>. Each row in the resultset is then iterated and passed to L</row_format_output> with the result of that call added to the output.

=cut

sub list_format_output
{
    my ($self, $c) = @_;

    my $rs = $c->req->current_result_set->search;
    $rs->result_class('DBIx::Class::ResultClass::HashRefInflator');

    try
    {
        my $output = {};
        my $formatted = [];

        foreach my $row ($rs->all)
        {
            push(@$formatted, $self->row_format_output($c, $row));
        }

        $output->{$self->data_root} = $formatted;

        if ($c->req->has_search_total_entries)
        {
            $output->{$self->total_entries_arg} = $c->req->search_total_entries + 0;
        }

        $c->stash->{response} = $output;
    }
    catch
    {
        $c->log->error($_);
        $self->push_error($c, { message => 'a database error has occured.' });
        $c->detach();
    }
}

=method_protected row_format_output

row_format_output is called each row of the inflated output generated from the search. It receives two arguments, the catalyst context and the hashref that represents the row. By default, this method is merely a passthrough.

=cut

sub row_format_output
{
    my ($self, $c, $row) = @_;
    return $row; # passthrough by default
}

=method_protected item

item will return a single object called by identifier in the uri. It will be inflated via each_object_inflate.

=cut

sub item
{
    my ($self, $c) = @_;

    if($c->req->count_objects != 1)
    {
        $c->log->error($_);
        $self->push_error($c, { message => 'No objects on which to operate' });
        $c->detach();
    }
    else
    {
        $c->stash->{response}->{$self->item_root} = $self->each_object_inflate($c, $c->req->get_object(0)->[0]);
    }
}

=method_protected update_or_create

update_or_create is responsible for iterating any stored objects and performing updates or creates. Each object is first validated to ensure it meets the criteria specified in the L</create_requires> and L</create_allows> (or L</update_allows>) parameters of the controller config. The objects are then committed within a transaction via L</transact_objects> using a closure around L</save_objects>.

=cut

sub update_or_create
{
    my ($self, $c) = @_;

    if($c->req->has_objects)
    {
        $self->validate_objects($c);
        $self->transact_objects($c, sub { $self->save_objects($c, @_) } );
    }
    else
    {
        $c->log->error($_);
        $self->push_error($c, { message => 'No objects on which to operate' });
        $c->detach();
    }
}

=method_protected transact_objects

transact_objects performs the actual commit to the database via $schema->txn_do. This method accepts two arguments, the context and a coderef to be used within the transaction. All of the stored objects are passed as an arrayref for the only argument to the coderef.

=cut

sub transact_objects
{
    my ($self, $c, $coderef) = @_;

    try
    {
        $self->stored_result_source->schema->txn_do
        (
            $coderef,
            $c->req->objects
        );
    }
    catch
    {
        $c->log->error($_);
        $self->push_error($c, { message => 'a database error has occured.' });
        $c->detach();
    }
}

=method_protected validate_objects

This is a shortcut method for performing validation on all of the stored objects in the request. Each object's provided values (for create or update) are updated to the allowed values permitted by the various config parameters.

=cut

sub validate_objects
{
    my ($self, $c) = @_;

    try
    {
        foreach my $obj ($c->req->all_objects)
        {
            $obj->[1] = $self->validate_object($c, $obj);
        }
    }
    catch
    {
        my $err = $_;
        $c->log->error($err);
        $err =~ s/\s+at\s+.+\n$//g;
        $self->push_error($c, { message => $err });
        $c->detach();
    }
}

=method_protected validate_object

validate_object takes the context and the object as an argument. It then filters the passed values in slot two of the tuple through the create|update_allows configured. It then returns those filtered values. Values that are not allowed are silently ignored. If there are no values for a particular key, no valid values at all, or multiple of the same key, this method will die.

=cut

sub validate_object
{
    my ($self, $c, $obj) = @_;
    my ($object, $params) = @$obj;

    my %values;
    my %requires_map = map
    {
        $_ => 1
    }
    @{
        ($object->in_storage)
        ? []
        : $c->stash->{create_requires} || $self->create_requires
    };

    my %allows_map = map
    {
        (ref $_) ? %{$_} : ($_ => 1)
    }
    (
        keys %requires_map,
        @{
            ($object->in_storage)
            ? ($c->stash->{update_allows} || $self->update_allows)
            : ($c->stash->{create_allows} || $self->create_allows)
        }
    );

    foreach my $key (keys %allows_map)
    {
        # check value defined if key required
        my $allowed_fields = $allows_map{$key};

        if (ref $allowed_fields)
        {
            my $related_source = $object->result_source->related_source($key);
            my $related_params = $params->{$key};
            my %allowed_related_map = map { $_ => 1 } @$allowed_fields;
            my $allowed_related_cols = ($allowed_related_map{'*'}) ? [$related_source->columns] : $allowed_fields;

            foreach my $related_col (@{$allowed_related_cols})
            {
                if (defined(my $related_col_value = $related_params->{$related_col})) {
                    $values{$key}{$related_col} = $related_col_value;
                }
            }
        }
        else
        {
            my $value = $params->{$key};

            if ($requires_map{$key})
            {
                unless (defined($value))
                {
                    # if not defined look for default
                    $value = $object->result_source->column_info($key)->{default_value};
                    unless (defined $value)
                    {
                        die "No value supplied for ${key} and no default";
                    }
                }
            }

            # check for multiple values
            if (ref($value) && !(reftype($value) eq reftype(JSON::Any::true)))
            {
                require Data::Dumper;
                die "Multiple values for '${key}': ${\Data::Dumper::Dumper($value)}";
            }

            # check exists so we don't just end up with hash of undefs
            # check defined to account for default values being used
            $values{$key} = $value if exists $params->{$key} || defined $value;
        }
    }

    unless (keys %values || !$object->in_storage)
    {
        die 'No valid keys passed';
    }

    return \%values;
}

=method_protected delete

delete operates on the stored objects in the request. It first transacts the objects, deleting them in the database using L</transact_objects> and a closure around L</delete_objects>, and then clears the request store of objects.

=cut

sub delete
{
    my ($self, $c) = @_;

    if($c->req->has_objects)
    {
        $self->transact_objects($c, sub { $self->delete_objects($c, @_) });
        $c->req->clear_objects;
    }
    else
    {
        $c->log->error($_);
        $self->push_error($c, { message => 'No objects on which to operate' });
        $c->detach();
    }
}

=method_protected save_objects

This method is used by update_or_create to perform the actual database manipulations. It iterates each object calling L</save_object>.

=cut

sub save_objects
{
    my ($self, $c, $objects) = @_;

    foreach my $obj (@$objects)
    {
        $self->save_object($c, $obj);
    }
}

=method_protected save_object

save_object first checks to see if the object is already in storage. If so, it calls L</update_object_from_params> otherwise it calls L</insert_object_from_params>

=cut

sub save_object
{
    my ($self, $c, $obj) = @_;

    my ($object, $params) = @$obj;

    if ($object->in_storage)
    {
        $self->update_object_from_params($c, $object, $params);
    }
    else
    {
        $self->insert_object_from_params($c, $object, $params);
    }

}

=method_protected update_object_from_params

update_object_from_params iterates through the params to see if any of them are pertinent to relations. If so it calls L</update_object_relation> with the object, and the relation parameters. Then it calls ->update on the object.

=cut

sub update_object_from_params
{
    my ($self, $c, $object, $params) = @_;

    foreach my $key (keys %$params)
    {
        my $value = $params->{$key};
        if (ref($value) && !(reftype($value) eq reftype(JSON::Any::true)))
        {
            $self->update_object_relation($c, $object, delete $params->{$key}, $key);
        }
        # accessor = colname
        elsif ($object->can($key)) {
            $object->$key($value);
        }
        # accessor != colname
        else {
            my $accessor = $object->result_source->column_info($key)->{accessor};
            $object->$accessor($value);
        }
    }

    $object->update();
}

=method_protected update_object_relation

update_object_relation finds the relation to the object, then calls ->update with the specified parameters

=cut

sub update_object_relation
{
    my ($self, $c, $object, $related_params, $relation) = @_;
    my $row = $object->find_related($relation, {} , {});

    if ($row) {
        foreach my $key (keys %$related_params) {
            my $value = $related_params->{$key};
            if (ref($value) && !(reftype($value) eq reftype(JSON::Any::true)))
            {
                $self->update_object_relation($c, $row, delete $related_params->{$key}, $key);
            }
            # accessor = colname
            elsif ($row->can($key)) {
                $row->$key($value);
            }
            # accessor != colname
            else {
                my $accessor = $row->result_source->column_info($key)->{accessor};
                $row->$accessor($value);
            }
        }
        $row->update();
    }
    else {
        $object->create_related($relation, $related_params);
    }
}

=method_protected insert_object_from_params

insert_object_from_params sets the columns for the object, then calls ->insert

=cut

sub insert_object_from_params
{
    my ($self, $c, $object, $params) = @_;

    my %rels;
    while (my ($k, $v) = each %{ $params }) {
        if (ref($v) && !(reftype($v) eq reftype(JSON::Any::true))) {
            $rels{$k} = $v;
        }
        else {
            $object->set_column($k => $v);
        }
    }

    $object->insert;

    while (my ($k, $v) = each %rels) {
        $object->create_related($k, $v);
    }
}

=method_protected delete_objects

delete_objects iterates through each object calling L</delete_object>

=cut

sub delete_objects
{
    my ($self, $c, $objects) = @_;

    map { $self->delete_object($c, $_->[0]) } @$objects;
}

=method_protected delete_object

Performs the actual ->delete on the object

=cut

sub delete_object
{
    my ($self, $c, $object) = @_;

    $object->delete;
}

=method_protected end

end performs the final manipulation of the response before it is serialized. This includes setting the success of the request both at the HTTP layer and JSON layer. If configured with return_object true, and there are stored objects as the result of create or update, those will be inflated according to the schema and get_inflated_columns

=cut

sub end :Private
{
    my ($self, $c) = @_;

    # check for errors
    my $default_status;

    # Check for errors caught elsewhere
    if ( $c->res->status and $c->res->status != 200 ) {
        $default_status = $c->res->status;
        $c->stash->{response}->{success} = $self->use_json_boolean ? JSON::Any::false : 'false';
    } elsif ($self->get_errors($c)) {
        $c->stash->{response}->{messages} = $self->get_errors($c);
        $c->stash->{response}->{success} = $self->use_json_boolean ? JSON::Any::false : 'false';
        $default_status = 400;
    } else {
        $c->stash->{response}->{success} = $self->use_json_boolean ? JSON::Any::true : 'true';
        $default_status = 200;
    }

    unless ($default_status == 200)
    {
        delete $c->stash->{response}->{$self->data_root};
    }
    elsif($self->return_object && $c->req->has_objects)
    {
        my $returned_objects = [];
        push(@$returned_objects, $self->each_object_inflate($c, $_)) for map { $_->[0] } $c->req->all_objects;
        $c->stash->{response}->{$self->data_root} = scalar(@$returned_objects) > 1 ? $returned_objects : $returned_objects->[0];
    }

    $c->res->status( $default_status || 200 );
    $c->forward('serialize');
}

=method_protected each_object_inflate

each_object_inflate executes during L</end> and allows hooking into the process of inflating the objects to return in the response. Receives, the context, and the object as arguments.

This only executes if L</return_object> if set and if there are any objects to actually return.

=cut

sub each_object_inflate
{
    my ($self, $c, $object) = @_;

    return { $object->get_columns };
}

# from Catalyst::Action::Serialize
sub serialize :ActionClass('Serialize') { }

=method_protected push_error

push_error stores an error message into the stash to be later retrieved by L</end>. Accepts a Dict[message => Str] parameter that defines the error message.

=cut

sub push_error
{
    my ( $self, $c, $params ) = @_;
    push( @{$c->stash->{_dbic_crud_errors}}, $params->{message} || 'unknown error' );
}

=method_protected get_errors

get_errors returns all of the errors stored in the stash

=cut

sub get_errors
{
    my ( $self, $c ) = @_;
    return $c->stash->{_dbic_crud_errors};
}

=head1 DESCRIPTION

Easily provide common API endpoints based on your L<DBIx::Class> schema classes. Module provides both RPC and REST interfaces to base functionality. Uses L<Catalyst::Action::Serialize> and L<Catalyst::Action::Deserialize> to serialise response and/or deserialise request.

=head1 OVERVIEW

This document describes base functionlity such as list, create, delete, update and the setting of config attributes. L<Catalyst::Controller::DBIC::API::RPC> and L<Catalyst::Controller::DBIC::API::REST> describe details of provided endpoints to those base methods.

You will need to create a controller for each schema class you require API endpoints for. For example if your schema has Artist and Track, and you want to provide a RESTful interface to these, you should create MyApp::Controller::API::REST::Artist and MyApp::Controller::API::REST::Track which both subclass L<Catalyst::Controller::DBIC::API::REST>. Similarly if you wanted to provide an RPC style interface then subclass L<Catalyst::Controller::DBIC::API::RPC>. You then configure these individually as specified in L</CONFIGURATION>.

Also note that the test suite of this module has an example application used to run tests against. It maybe helpful to look at that until a better tutorial is written.

=head2 CONFIGURATION

Each of your controller classes needs to be configured to point at the relevant schema class, specify what can be updated and so on, as shown in the L</SYNOPSIS>.

The class, create_requires, create_allows and update_requires parameters can also be set in the stash like so:

  sub setup :Chained('/api/rpc/rpc_base') :CaptureArgs(1) :PathPart('any') {
    my ($self, $c, $object_type) = @_;

    if ($object_type eq 'artist') {
      $c->stash->{class} = 'MyAppDB::Artist';
      $c->stash->{create_requires} = [qw/name/];
      $c->stash->{update_allows} = [qw/name/];
    } else {
      $self->push_error($c, { message => "invalid object_type" });
      return;
    }

    $self->next::method($c);
  }

Generally it's better to have one controller for each DBIC source with the config hardcoded, but in some cases this isn't possible.

Note that the Chained, CaptureArgs and PathPart are just standard Catalyst configuration parameters and that then endpoint specified in Chained - in this case '/api/rpc/rpc_base' - must actually exist elsewhere in your application. See L<Catalyst::DispatchType::Chained> for more details.

Below are explanations for various configuration parameters. Please see L<Catalyst::Controller::DBIC::API::StaticArguments> for more details.

=head3 class

Whatever you would pass to $c->model to get a resultset for this class. MyAppDB::Track for example.

=head3 data_root

By default, the response data is serialized into $c->stash->{response}->{$self->data_root} and data_root defaults to 'list' to preserve backwards compatibility. This is now configuable to meet the needs of the consuming client.

=head3 use_json_boolean

By default, the response success status is set to a string value of "true" or "false". If this attribute is true, JSON::Any's true() and false() will be used instead. Note, this does not effect other internal processing of boolean values.

=head3 count_arg, page_arg, select_arg, search_arg, grouped_by_arg, ordered_by_arg, prefetch_arg, as_arg, total_entries_arg

These attributes allow customization of the component to understand requests made by clients where these argument names are not flexible and cannot conform to this components defaults.

=head3 create_requires

Arrayref listing columns required to be passed to create in order for the request to be valid.

=head3 create_allows

Arrayref listing columns additional to those specified in create_requires that are not required to create but which create does allow. Columns passed to create that are not listed in create_allows or create_requires will be ignored.

=head3 update_allows

Arrayref listing columns that update will allow. Columns passed to update that are not listed here will be ignored.

=head3 select

Arguments to pass to L<DBIx::Class::ResultSet/select> when performing search for L</list>.

=head3 as

Complements arguments passed to L<DBIx::Class::ResultSet/select> when performing a search. This allows you to specify column names in the result for RDBMS functions, etc.

=head3 select_exposes

Columns and related columns that are okay to return in the resultset since clients can request more or less information specified than the above select argument.

=head3 prefetch

Arguments to pass to L<DBIx::Class::ResultSet/prefetch> when performing search for L</list>.

=head3 prefetch_allows

Arrayref listing relationships that are allowed to be prefetched.
This is necessary to avoid denial of service attacks in form of
queries which would return a large number of data
and unwanted disclosure of data.

=head3 grouped_by

Arguments to pass to L<DBIx::Class::ResultSet/group_by> when performing search for L</list>.

=head3 ordered_by

Arguments to pass to L<DBIx::Class::ResultSet/order_by> when performing search for L</list>.

=head3 search_exposes

Columns and related columns that are okay to search on. For example if only the position column and all cd columns were to be allowed

 search_exposes => [qw/position/, { cd => ['*'] }]

You can also use this to allow custom columns should you wish to allow them through in order to be caught by a custom resultset. For example:

  package RestTest::Controller::API::RPC::TrackExposed;

  ...

  __PACKAGE__->config
    ( ...,
      search_exposes => [qw/position title custom_column/],
    );

and then in your custom resultset:

  package RestTest::Schema::ResultSet::Track;

  use base 'RestTest::Schema::ResultSet';

  sub search {
    my $self = shift;
    my ($clause, $params) = @_;

    # test custom attrs
    if (my $pretend = delete $clause->{custom_column}) {
      $clause->{'cd.year'} = $pretend;
    }
    my $rs = $self->SUPER::search(@_);
  }

=head3 count

Arguments to pass to L<DBIx::Class::ResultSet/rows> when performing search for L</list>.

=head3 page

Arguments to pass to L<DBIx::Class::ResultSet/rows> when performing search for L</list>.

=head1 EXTENDING

By default the create, delete and update actions will not return anything apart from the success parameter set in L</end>, often this is not ideal but the required behaviour varies from application to application. So normally it's sensible to write an intermediate class which your main controller classes subclass from.

For example if you wanted create to return the JSON for the newly created object you might have something like:

  package MyApp::ControllerBase::DBIC::API::RPC;
  ...
  use Moose;
  BEGIN { extends 'Catalyst::Controller::DBIC::API::RPC' };
  ...
  sub create :Chained('setup') :Args(0) :PathPart('create') {
    my ($self, $c) = @_;

    # $c->req->all_objects will contain all of the created
    $self->next::method($c);

    if ($c->req->has_objects) {
      # $c->stash->{response} will be serialized in the end action
      $c->stash->{response}->{$self->data_root} = [ map { { $_->get_inflated_columns } } ($c->req->all_objects) ] ;
    }
  }

  package MyApp::Controller::API::RPC::Track;
  ...
  use Moose;
  BEGIN { extends 'MyApp::ControllerBase::DBIC::API::RPC' };
  ...

It should be noted that the return_object attribute will produce the above result for you, free of charge.

Similarly you might want create, update and delete to all forward to the list action once they are done so you can refresh your view. This should also be simple enough.

If more extensive customization is required, it is recommened to peer into the roles that comprise the system and make use

=head1 NOTES

It should be noted that version 1.004 and above makes a rapid depature from the status quo. The internals were revamped to use more modern tools such as Moose and its role system to refactor functionality out into self-contained roles.

To this end, internally, this module now understands JSON boolean values (as represented by JSON::Any) and will Do The Right Thing in handling those values. This means you can have ColumnInflators installed that can covert between JSON::Any booleans and whatever your database wants for boolean values.

Validation for various *_allows or *_exposes is now accomplished via Data::DPath::Validator with a lightly simplified, via subclass, Data::DPath::Validator::Visitor. The rough jist of the process goes as follows: Arguments provided to those attributes are fed into the Validator and Data::DPaths are generated. Then, incoming requests are validated against these paths generated. The validator is set in "loose" mode meaning only one path is required to match. For more information, please see L<Data::DPath::Validator> and more specifically L<Catalyst::Controller::DBIC::API::Validator>.

Since 2.00100:
Transactions are used. The stash is put aside in favor of roles applied to the request object with additional accessors.
Error handling is now much more consistent with most errors immediately detaching.
The internals are much easier to read and understand with lots more documentation.

=cut

1;
