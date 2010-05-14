#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 4;
use Rose::DBx::TestDB;
use Rose::DB::Object;
use_ok('Rose::DBx::Object::MoreHelpers');

{

    package MyRDBO;
    @MyRDBO::ISA = qw(Rose::DB::Object Rose::DBx::Object::MoreHelpers);

    MyRDBO->meta->setup(
        table => 'no_such_table',

        columns => [
            id   => { type => 'varchar' },
            name => { type => 'varchar', length => 16 },
        ],

        primary_key_columns => [ 'id', 'name' ],
    );

    sub init_db { return Rose::DBx::TestDB->new }

}

ok( my $rdbo = MyRDBO->new( id => '1;2', name => '3/4' ), "new rdbo object" );
ok( my $pk_uri_escaped = $rdbo->primary_key_uri_escaped(),
    "get pk uri escaped" );
is( $pk_uri_escaped, "1%3b2;;3%2f4", "pk escaped" );
