package TestHelper;
BEGIN {$^W = 1};
use strict;
use File::Spec;
use File::Path;
use Cwd;
use Config;

sub create_dist {
    my ($self, $dist) = @_;
    my $dist_path = File::Spec->catdir('t', $dist);
    return 0 if -d $dist_path;
    my $home = cwd;
    mkdir($dist_path, 0777) or return 0;
    chdir $dist_path or return 0;

    open MANIFEST, '> MANIFEST' or return 0;
    print MANIFEST <<END;
MANIFEST
Makefile.PL
$dist.pm
END
    close MANIFEST;

    open MAKEFILE_PL, '> Makefile.PL' or return 0;
    print MAKEFILE_PL <<END;
use CPAN::MakeMaker;
WriteMakefile;
END
    close MAKEFILE_PL;

    open MODULE, "> $dist.pm" or return 0;
    print MODULE <<END;
package $dist;
\$VERSION = '3.21';
use strict;

1;
__END__
=head1 NAME

$dist - A test module

=cut
END
    close MODULE;
    chdir $home or return 0;
    return 1;
}

sub build_dist {
    my ($self, $dist) = @_;
    my $dist_path = File::Spec->catdir('t', $dist);
    return 0 unless -d $dist_path;
    my $home = cwd;
    chdir $dist_path or return 0;
    my $perl = $Config::Config{perlpath};
    system("$perl -Mblib Makefile.PL") == 0 or return 0;
    chdir $home or return 0;
    return 1;
}
    
sub kill_dist {
    my ($self, $dist) = @_;
    my $dist_path = File::Spec->catdir('t', $dist);
    File::Path::rmtree($dist_path) or return 0;
    return 1; 
}

1;
