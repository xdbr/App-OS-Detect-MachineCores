package App::OS::Detect::MachineCores;

#  PODNAME: App::OS::Detect::MachineCores
# ABSTRACT: Detect how many cores your machine has (OS-independently)

use true;
use Carp;
use 5.010;
use strict;
use warnings;

use Moo;
use MooX::Options skip_options => [qw<os cores>];
use Module::Load::Conditional qw/can_load/;
use IPC::Open2;

has os => (
    is       => 'ro',
    required => 1,
    default  => sub { $^O },
);

has cores => (
    is      => 'rw',
    isa     => sub { die "$_[0] is not a reasonable number of cores!" unless $_[0] > 0 and $_[0] < 100 },
    lazy    => 1,
    builder => '_build_cores',
);

option add_one => (
    is      => 'rw',
    isa     => sub { die "Invalid bool!" unless $_[0] == 0 or $_[0] == 1 },
    default => sub { '0' },
    short   => 'i',
    doc     => q{add one to the number of cores (useful in scripts)},
);

sub _build_cores {
    my $cores;
    my $ffi = can_load( modules => { 'FFI::Platypus' => undef } ) ? FFI::Platypus->new();
    if ($ffi) {
        $ffi->lib(undef);
        $cores = eval { $ffi->function( sysconf => ['int'] => 'long' )->call(84) };
    }
    if (!$cores) {
        my $cmd;
        for ($_[0]->os) {
            when ('linux')   { $cmd = 'grep -c processor /proc/cpuinfo' }
            when ('darwin')  { $cmd = 'sysctl hw.ncpu | awk \'{print \$2}\'' }
            when ('MSWin32') { $cmd = 'echo %NUMBER_OF_PROCESSORS%' }
            default { carp "Can't detect the cores for your system/OS, sorry."; return 0; }
        }
        waitpid( open2(my $out, my $in, $cmd), 0);
        $cores = <$out> + 0;
    }
}

around cores => sub {
    my ($orig, $self) = (shift, shift);

    return $self->$orig() + 1 if $self->add_one;
    return $self->$orig();
};

no Moo;


=for Pod::Coverage os cores _build_cores add_one

=begin wikidoc

= SYNOPSIS

On different system, different approaches are needed to detect the number of cores for that machine.

This Module is a wrapper around these different approaches.

= USAGE

This module will install one executable, {mcores}, in your bin.

It is really simple and straightforward:

    usage: mcores [-?i] [long options...]
        -h --help       Prints this usage information.
        -i --add_one    add one to the number of cores (useful in scripts)

= SUPPORTED SYSTEMS

* darwin (OSX)
* Linux

= MOTIVATION

During development of dotfiles for different platforms I was searching for some way to be able to
transparantly detect the number of available cores and couldn't find one.
Also it is quite handy to be able to increment the number by simply using a little switch {-i}.

Example:
    export TEST_JOBS=`mcores -i`

=end wikidoc
