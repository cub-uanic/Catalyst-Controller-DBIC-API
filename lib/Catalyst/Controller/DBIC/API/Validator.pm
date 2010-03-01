package Catalyst::Controller::DBIC::API::Validator;
#ABSTRACT: Provides validation services for inbound requests against whitelisted parameters
use Moose;
use namespace::autoclean;

BEGIN { extends 'Data::DPath::Validator'; }

has '+visitor' => ( 'builder' => '_build_custom_visitor' );

sub _build_custom_visitor
{
    return Catalyst::Controller::DBIC::API::Visitor->new();
}

Catalyst::Controller::DBIC::API::Validator->meta->make_immutable;

###############################################################################
package Catalyst::Controller::DBIC::API::Visitor;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Data::DPath::Validator::Visitor'; }

use constant DEBUG => $ENV{DATA_DPATH_VALIDATOR_DEBUG} || 0;

around visit_array => sub
{
    my ($orig, $self, $array) = @_;
    $self->dive();
    warn 'ARRAY: '. $self->current_template if DEBUG;
    if(@$array == 1 && $array->[0] eq '*')
    {
        $self->append_text('[reftype eq "HASH" ]');
        $self->add_template($self->current_template);
    }
    else
    {
        if($self->current_template =~ /\/$/)
        {
            my $temp = $self->current_template;
            $self->reset_template();
            $temp =~ s/\/$//;
            $self->append_text($temp);
        }
        $self->$orig($array);
    }
    $self->rise();
};

sub visit_array_entry
{
    my ($self, $elem, $index, $array) = @_;
    $self->dive();
    warn 'ARRAYENTRY: '. $self->current_template if DEBUG;
    if(!ref($elem))
    {
        $self->append_text($elem . '/*');
        $self->add_template($self->current_template);
    }
    elsif(ref($elem) eq 'HASH')
    {
        $self->visit($elem);
    }
    $self->rise();
    $self->value_type('NONE');
};

around visit_hash => sub
{
    my ($orig, $self, $hash) = @_;
    $self->dive();
    if($self->current_template =~ /\/$/)
    {
        my $temp = $self->current_template;
        $self->reset_template();
        $temp =~ s/\/$//;
        $self->append_text($temp);
    }
    warn 'HASH: '. $self->current_template if DEBUG;
    $self->$orig($hash);
    $self->rise();
};

around visit_value => sub
{
    my ($orig, $self, $val) = @_;

    if($self->value_type eq 'NONE')
    {
        $self->dive();
        $self->append_text($val . '/*');
        $self->add_template($self->current_template);
        warn 'VALUE: ' . $self->current_template if DEBUG;
        $self->rise();
    }
    elsif($self->value_type eq 'HashKey')
    {
        $self->append_text($val);
        warn 'VALUE: ' . $self->current_template if DEBUG;
    }
    else
    {
        $self->$orig($val);
    }

};


Catalyst::Controller::DBIC::API::Visitor->meta->make_immutable;

1;
