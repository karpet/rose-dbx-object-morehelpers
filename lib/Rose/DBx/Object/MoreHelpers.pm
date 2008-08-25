package Rose::DBx::Object::MoreHelpers;

use warnings;
use strict;

use Rose::Object::MixIn;
our @ISA = qw(Rose::Object::MixIn);

use Carp;
use Data::Dump qw( dump );
use Scalar::Util qw( blessed );

use Rose::DB::Object::Manager;
use Rose::DB::Object::Metadata::Relationship::OneToMany;
Rose::DB::Object::Metadata::Relationship::OneToMany
    ->default_auto_method_types(
    qw(
        find
        get_set_on_save
        add_on_save
        count
        iterator
        )
    );
use Rose::DB::Object::Metadata::Relationship::ManyToMany;
Rose::DB::Object::Metadata::Relationship::ManyToMany
    ->default_auto_method_types(
    qw(
        find
        get_set_on_save
        add_on_save
        count
        iterator
        )
    );

use Rose::Class::MakeMethods::Generic ( scalar => ['debug'], );

our $VERSION = '0.01';

__PACKAGE__->export_tags(
    all => [
        qw(
            primary_key_uri_escaped primary_key_value
            flatten exists has_related has_related_pages
            fetch_all fetch_all_iterator
            )
    ],

    # This exists for the benefit of the test suite
    all_noprereq => [
        qw(
            primary_key_uri_escaped primary_key_value
            flatten exists has_related has_related_pages
            fetch_all fetch_all_iterator
            )
    ],
);

=head1 NAME

Rose::DBx::Object::MoreHelpers - more mixin helpers for RDBO

=head1 SYNOPSIS

 package MyRDBO;
 use base qw( Rose::DB::Object );
 use Rose::DBx::Object::MoreHelpers;
 
=head1 DESCRIPTION

In the tradition of Rose::DB::Object::Helpers, more importable methods.

This class inherits from Rose::Object::MixIn. 
See the Rose::Object::MixIn documentation for 
a full explanation of how to import methods from this class. 
The helper methods themselves are described below.

=head1 METHODS

MoreHelpers changes the default relationship method makers to include:

 find
 get_set_on_save
 add_on_save
 count
 iterator

=cut

=head2 primary_key_uri_escaped

Returns the primary key value, URI-escaped. If there are multiple
columns comprising the primary key, they are joined into a single
string.

If there are no values set for any of the column(s) comprising
the primary key, returns 0.

Otherwise, returns all column values joined with C<;;> as per
CatalystX::CRUD::Controller API.

=cut

sub primary_key_uri_escaped {
    my $self = shift;
    my $val  = $self->primary_key_value;
    my @vals = ref $val ? @$val : ($val);
    my @esc;
    for my $v (@vals) {
        $v = '' unless defined $v;
        $v =~ s/;/ sprintf( "%%%02X", ';' ) /eg;
        push @esc, $v;
    }
    if ( !grep { length($_) } @esc ) {
        return 0;
    }
    my $pk = join( ';;', @esc );
    return $pk;
}

=head2 primary_key_value

Returns the value of the primary key column(s). If the
value is comprised of multiple column values, the return
value will be an array ref of values.

=cut

sub primary_key_value {
    my $self = shift;
    my @cols = $self->meta->primary_key_column_names;
    my @vals;
    for my $m (@cols) {
        push( @vals, scalar $self->$m );
    }
    return scalar(@vals) > 1 ? \@vals : $vals[0];
}

=head2 flatten

Returns the serialized object and its immediately related objects.

TODO this method does not yet support column aliases.

=cut

sub flatten {
    my $self  = shift;
    my $pairs = shift || $self->column_value_pairs;
    my %flat  = %$pairs;
    for ( keys %flat ) {
        if ( blessed( $flat{$_} ) and $flat{$_}->isa('DateTime') ) {
            $flat{$_} = "$flat{$_}";
        }
    }
    for my $rel ( $self->meta->relationships ) {
        my $method = $rel->name;
        my $val    = $self->$method;
        next unless defined $val;
        if ( ref $val eq 'ARRAY' ) {
            my @flattened;
            for my $obj (@$val) {
                $obj->strip( leave => 'related_objects' );
                my $f = $obj->column_value_pairs;
                for ( keys %$f ) {
                    if ( blessed( $f->{$_} ) && $f->{$_}->isa('DateTime') ) {
                        $f->{$_} = "$f->{$_}";
                    }
                }
                push( @flattened, $f );
            }
            $flat{$method} = \@flattened;
        }
        elsif ( blessed($val) and $val->isa('Rose::DB::Object') ) {

            #$val->strip( leave => 'related_objects' );
            $flat{$method} = $val->flatten;
        }
        else {

            #$val->strip( leave => 'related_objects' );
            $flat{$method} = $val->flatten;
        }
    }
    return \%flat;
}

=head2 exists( [ @I<params> ] )

Returns true if the object exists in the database, false otherwise.

May be called as class or object method.

This method uses the Rose::DB::Object::Manager class to check
the database based on non-unique column(s). Call it like you
would load_speculative() but when you do not have a unique combination
of columns (which all the load* methods require).

When called as object method, if @I<params> is omitted, 
the current column values of the object are used.

Example:

 # 'title' has no unique constraints on it
 my $object = Object->new(title => 'Foo');
 $object->save unless $object->exists;

B<NOTE:> Using exists() as a way of enforcing data integrity
is far inferior to actually placing a constraint on a table
in the database. However, for things like testing and development
data, it can be a useful utility method.

=cut

sub exists {
    my $self = shift;
    my @arg  = @_;
    if ( !@arg && ref($self) ) {

        # TODO use *method_name* instead ?
        for my $col ( $self->meta->column_names ) {
            push( @arg, $col, $self->$col ) if defined( $self->$col );
        }
    }
    my $count = Rose::DB::Object::Manager->get_objects_count(
        object_class => ref($self) || $self,
        query => [@arg]
    );

    return $count if defined($count);
    croak "Error: " . Rose::DB::Object::Manager->error;
}

=head2 has_related( I<relationship_name> )

Returns the number of related objects defined by the I<relationship_name>
accessor.

Just a wrapper around the B<count> RDBO method type.

=cut

sub has_related {
    my $self   = shift;
    my $rel    = shift or croak "need Relationship name";
    my $method = $rel . '_count';
    return $self->$method;
}

=head2 has_related_pages( I<relationship_name>, I<page_size> )

Returns the number of "pages" given I<page_size> for the count of related
object for I<relationship_name>. Useful for creating pagers.

=cut

sub has_related_pages {
    my $self   = shift;
    my $rel    = shift or croak "need Relationship name";
    my $pgsize = shift or croak "need page_size";
    if ( $pgsize =~ m/\D/ ) {
        croak "page_size must be an integer";
    }
    my $n = $self->has_related($rel);
    return 0 if !$n;
    if ( $n % $pgsize ) {
        return int( $n / $pgsize ) + 1;
    }
    else {
        return $n / $pgsize;
    }
}

=head2 fetch_all

Shortcut for the Manager method get_objects().

=cut

sub fetch_all {
    my $self  = shift;
    my $class = $self->meta->class;
    return Rose::DB::Object::Manager->get_objects(
        object_class => $class,
        @_
    );
}

=head2 fetch_all_iterator

Shortcut for the Manager method get_objects_iterator().

=cut

sub fetch_all_iterator {
    my $self  = shift;
    my $class = $self->meta->class;
    return Rose::DB::Object::Manager->get_objects_iterator(
        object_class => $class,
        @_
    );
}

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-rose-dbx-object-morehelpers at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Rose-DBx-Object-MoreHelpers>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Rose::DBx::Object::MoreHelpers

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Rose-DBx-Object-MoreHelpers>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Rose-DBx-Object-MoreHelpers>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Rose-DBx-Object-MoreHelpers>

=item * Search CPAN

L<http://search.cpan.org/dist/Rose-DBx-Object-MoreHelpers>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2008 Peter Karman, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Rose::DBx::Object::MoreHelpers
