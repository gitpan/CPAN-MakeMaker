use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'CPAN::MakeMaker',
    VERSION_FROM => 'MakeMaker.pm',
    clean => { FILES => 't/Foo' },
);
