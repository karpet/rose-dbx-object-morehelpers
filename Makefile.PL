use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Rose::DBx::Object::MoreHelpers',
    AUTHOR              => 'Peter Karman <karman@cpan.org>',
    VERSION_FROM        => 'lib/Rose/DBx/Object/MoreHelpers.pm',
    ABSTRACT_FROM       => 'lib/Rose/DBx/Object/MoreHelpers.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Rose::DB::Object' => 0.770,
        'Rose::DBx::TestDB' => 0,
        'Scalar::Util'  => 0,
        'Data::Dump'    => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Rose-DBx-Object-MoreHelpers-*' },
);
