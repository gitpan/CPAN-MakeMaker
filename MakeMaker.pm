package CPAN::MakeMaker;
use strict;
use File::Spec;

sanity_checks();
write_self();
load_self();

#==============================================================================
# Print a message
#==============================================================================
sub PRINT {
    my @args = @_;
    chomp $args[-1];
    print @args, "\n";
}

#==============================================================================
# Get a grip!
#==============================================================================
sub sanity_checks {
    die <<END unless $0 =~ /Makefile\.PL$/ and -f 'Makefile.PL';
CPAN::MakeMaker should only be used inside Makefile.PL
END
}

#==============================================================================
# Write CPAN::MakeMaker into existence
#==============================================================================
my $self;
sub write_self {
    my $filepath = File::Spec->catfile(qw(CPAN MakeMaker.pm));
    return if -f $filepath;

    PRINT 'Creating CPAN directory';
    mkdir('CPAN', 0777) unless -d 'CPAN';
    PRINT 'Creating CPAN/MakeMaker.pm';
    open MAKEMAKER, "> $filepath" or die $!;
    print MAKEMAKER $self;
    close MAKEMAKER;
}

#==============================================================================
# And away we go
#==============================================================================
sub load_self {
    delete $INC{'CPAN/MakeMaker.pm'};
#XXX this should work
#   my $filepath = File::Spec->catfile(# File::Spec->curdir,
#                                      qw(CPAN MakeMaker.pm));
    my $filepath = "./CPAN/MakeMaker.pm";
    require "$filepath";
}

#==============================================================================
# This is the actual code of CPAN::MakeMaker stored into a string.
#==============================================================================
BEGIN {
    (undef, $self) = (<<END_VIM_TRICK, <<'END_MAKEMAKER');
The vim editor has a bug. It only recognizes the first here-document for
Perl syntax highlighting. Since it is harder for me to grok code when it
is all purple, I exploit this bug to my advantage. :-)
END_VIM_TRICK
package CPAN::MakeMaker;
$VERSION = '0.10';
@EXPORT = qw(WriteMakefile prompt);
use strict;
use ExtUtils::MakeMaker();
use File::Spec;
use Cwd;
use base 'Exporter';
*prompt = \&ExtUtils::MakeMaker::prompt;
sub PRINT;
if (not defined &PRINT) {
    *PRINT = sub { my @args = @_; chomp $args[-1]; print @args, "\n"; };
}

sub WriteMakefile {
    my %args = @_;
    $args{NAME} = determine_NAME()
      unless defined $args{NAME};
    $args{VERSION} = determine_VERSION()
      unless defined $args{VERSION} or defined $args{VERSION_FROM};
    update_manifest();

    ExtUtils::MakeMaker::WriteMakefile(%args);
    append_to_makefile();
}

sub determine_NAME {
    my $NAME = '';
    my @modules = glob('*.pm'), grep {/\.pm$/} find_files('lib');
    if (@modules == 1) {
        open MODULE, $modules[0] or die $!;
        while (<MODULE>) {
            next if /^\s*#/;
            if (/^\s*package\s+(\w[\w:]*)\s*;\s*$/) {
                $NAME = $1;
            }
            last;
        }
    }
    die <<END unless length($NAME);
Can't determine a NAME for this distribution.
Please pass a NAME parameter to the WriteMakefile function in Makefile.PL.
END
    return $NAME;
}

sub find_files {
    my ($file, $path) = @_;
    $path = '' if not defined $path;
    $file = "$path/$file" if length($path);
    if (-f $file) {
        return ($file);
    }
    elsif (-d $file) {
        my @files = ();
        local *DIR;
        opendir(DIR, $file) or die "Can't opendir $file";
        while (my $new_file = readdir(DIR)) {
            next if $new_file =~ /^(\.|\.\.)$/;
            push @files, find_files($new_file, $file);
        }
        return @files;
    }
    return ();
}
    
sub determine_VERSION {
    my $VERSION = '';
    my @modules = glob('*.pm'), grep {/\.pm$/} find_files('lib');
    if (@modules == 1) {
        eval {
            $VERSION = ExtUtils::MM_Unix->parse_version($modules[0]);
        };
        print STDERR $@ if $@;
    }
    die <<END unless length($VERSION);
Can't determine a VERSION for this distribution.
Please pass a VERSION parameter to the WriteMakefile function in Makefile.PL.
END
    return $VERSION;
}

sub update_manifest {
    my ($manifest, $manifest_path, $relative_path) = read_manifest();
    my $manifest_changed = 0;

    my %manifest;
    for (@$manifest) {
        my $path = $_;
        chomp $path;
        $path =~ s/^\.[\\\/]//;
        $path =~ s/[\\\/]/\//g;
        $manifest{$path} = 1;
    }

    for (find_files('CPAN')) {
        my $filepath = $_;
        $filepath = "$relative_path/$filepath"
          if length($relative_path);
        unless (defined $manifest{$filepath}) {
            PRINT 'Updating your MANIFEST file:'
              unless $manifest_changed++;
            PRINT "  Adding '$filepath'";
            push @$manifest, "$filepath\n";
            $manifest{$filepath} = 1;
        }
    }

    if ($manifest_changed) {
        open MANIFEST, "> $manifest_path" 
          or die "Can't open '$manifest_path' for output:\n$!";
        print MANIFEST for @$manifest;
        close MANIFEST;
    }
}

sub read_manifest {
    my $manifest = [];
    my $manifest_path = '';
    my $relative_path = '';
    my @relative_dirs = ();
    my $cwd = cwd();
    my @cwd_dirs = File::Spec->splitdir($cwd);
    while (@cwd_dirs) {
        last unless -f File::Spec->catfile(@cwd_dirs, 'Makefile.PL');
        my $path = File::Spec->catfile(@cwd_dirs, 'MANIFEST');
        if (-f $path) {
            $manifest_path = $path;
            last;
        }
        unshift @relative_dirs, pop(@cwd_dirs);
    }
    unless (length($manifest_path)) {
        die "Can't locate the MANIFEST file for '$cwd'\n";
    }
    $relative_path = join '/', @relative_dirs
      if @relative_dirs;

    open MANIFEST, $manifest_path 
      or die "Can't open $manifest_path for input:\n$!";
    @$manifest = <MANIFEST>;
    close MANIFEST;

    return ($manifest, $manifest_path, $relative_path);
}

sub append_to_makefile {
    open MAKEFILE, '>> Makefile'
      or die "CPAN::MakeMaker::WriteMakefile can't append to Makefile:\n$!";

    print MAKEFILE <<MAKEFILE;
# Well, not quite. CPAN::MakeMaker is adding this:

.PHONY = cpurge chelp

# The cpurge target can be used by the author of this module to remove
# files added by CPAN::MakeMaker. The files will not be removed from
# the MANIFEST. You'll need to do that yourself.
cpurge :: purge
	\$(RM_RF) CPAN

# Authors can use this target as a shortcut for 'perldoc CPAN::MakeMaker'
chelp ::
	perldoc CPAN::MakeMaker

# The End is here ==>
MAKEFILE

    close MAKEFILE;
}

1;

END_MAKEMAKER
}

1;
