package EvalServer::Seccomp;

use strict;
use warnings;

use Data::Dumper;
use List::Util qw/reduce/;
use Moo;
use Sys::Linux::Unshare qw/:consts/;
use POSIX;
use Linux::Seccomp;
use Carp qw/croak/;

has exec_map => (is => 'ro', default => sub {
  # TODO this should actually end up in eval.pl specifically.
    return {
     'perl4' =>    {bin => '/perl5/perlbrew/perls/perl-4.036/bin/perl'},
     'perl5.5' =>  {bin => '/perl5/perlbrew/perls/perl-5.005_04/bin/perl'},
     'perl5.6' =>  {bin => '/perl5/perlbrew/perls/perl-5.6.2/bin/perl'},
     'perl5.8' =>  {bin => '/perl5/perlbrew/perls/perl-5.8.9/bin/perl'},
     'perl5.10' => {bin => '/perl5/perlbrew/perls/perl-5.10.1/bin/perl'},
     'perl5.12' => {bin => '/perl5/perlbrew/perls/perl-5.12.5/bin/perl'},
     'perl5.14' => {bin => '/perl5/perlbrew/perls/perl-5.14.4/bin/perl'},
     'perl5.16' => {bin => '/perl5/perlbrew/perls/perl-5.16.3/bin/perl'},
     'perl5.18' => {bin => '/perl5/perlbrew/perls/perl-5.18.4/bin/perl'},
     'perl5.20' => {bin => '/perl5/perlbrew/perls/perl-5.20.3/bin/perl'},
     'perl5.22' => {bin => '/perl5/perlbrew/perls/perl-5.22.3/bin/perl'},
     'perl5.24' => {bin => '/perl5/perlbrew/perls/perl-5.24.0/bin/perl'},
     'ruby'     => {bin => '/usr/bin/ruby2.1'},
    };
  });

has profiles => (is => 'ro'); # aref

has _rules => (is => 'rw');

has seccomp => (is => 'ro', default => sub {Linux::Seccomp->new(SCMP_ACT_KILL)});

# Define some more open modes that POSIX doesn't have for us.
my ($O_DIRECTORY, $O_CLOEXEC, $O_NOCTTY, $O_NOFOLLOW) = (00200000, 02000000, 00000400, 00400000);

# TODO this needs some accessors to make it easier to define rulesets
our %rule_sets = {
  default => {
    include => ['time_calls', 'file_readonly', 'stdio', 'exec_wrapper'],
    rules => [{syscall => 'mmap'},
              {syscall => 'munmap'},
              {syscall => 'mremap'},
              {syscall => 'mprotect'},
              {syscall => 'brk'},

              {syscall => 'exit'},
              {syscall => 'exit_group'},
              {syscall => 'rt_sigaction'},
              {syscall => 'rt_sigprocmask'},

              {syscall => 'getuid'},
              {syscall => 'geteuid'},
              {syscall => 'getcwd'},
              {syscall => 'getpid'},
              {syscall => 'getgid'},
              {syscall => 'getegid'},
              {syscall => 'getgroups'},
    
              {syscall => 'access'}, # file_* instead?
              {syscall => 'readlink'},
              
              {syscall => 'arch_prctl'},
              {syscall => 'set_tid_address'},
              {syscall => 'set_robust_list'},
              {syscall => 'futext'},
              {syscall => 'getrlimit'},
    ],
  },

  # File related stuff
  stdio => {
    rules => [{syscall => 'read', args => [[qw|0 == 0|]]},  # STDIN
              {syscall => 'write', args => [[qw|0 == 1|]]}, # STDOUT
              {syscall => 'write', args => [[qw|0 == 2|]]},
              ],
  },
  file_open => {
    rules => [{syscall => 'open',   permute_args => [['1', '==', \'open_modes']]}, 
              {syscall => 'openat', permute_args => [['2', '==', \'open_modes']]},
              {syscall => 'close'},
              {syscall => 'select'},
              {syscall => 'read'},
              {syscall => 'lseek'},
              {syscall => 'fstat'}, # default? not file_open?
              {syscall => 'stat'},
              {syscall => 'lstat'},
              {syscall => 'fcntl'},
              # 4352  ioctl(4, TCGETS, 0x7ffd10963820)  = -1 ENOTTY (Inappropriate ioctl for device)
              # This happens on opened files for some reason? wtf
              {syscall => 'ioctl', rules =>[[1, '==', 0x5401]]},
              ],
  },
  file_opendir => {
    permute => {open_modes => [$O_DIRECTORY]},
    rules => [{syscall => 'getdents'}],
    include => ['file_open'],
  },
  file_tty => {
    permute => {open_modes => [$O_NOCTTY, ]},
    include => ['file_open'],
  },
  file_readonly => { 
    permute => {open_modes => [&POSIX::O_NONBLOCK, &POSIX::O_EXCL, &POSIX::O_RDONLY, $O_NOFOLLOW, $O_CLOEXEC]},
    include => ['file_open'],
  },
  file_write => {
    permute => {open_modes => [&POSIX::O_CREAT,&POSIX::O_WRONLY, &POSIX::O_TRUNC, &POSIX::O_RDWR]},
    rules => [{syscall => 'write'}],
    include => ['file_open', 'file_readonly'],
  },

  # time related stuff
  time_calls => {
    rules => [
      {syscall => 'nanosleep'},
      {syscall => 'clock_gettime'},
      {syscall => 'clock_getres'},
    ],
  },

  # ruby timer threads
  ruby_timer_thread => {
#    permute => {clone_flags => []},
    rules => [
      {syscall => 'clone', rules => [[0, '==', CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND|CLONE_THREAD|CLONE_SYSVSEM|CLONE_SETTLS|CLONE_PARENT_SETTID|CLONE_CHILD_CLEARTID]]},

      # Only allow a new signal stack context to be created, and only with a size of 8192 bytes.  exactly what ruby does
      # Have to allow it to be blind since i can't inspect inside the struct passed to it :(  I'm not sure how i feel about this one
      {syscall => 'sigaltstack', }, #=> rules [[1, '==', 0], [2, '==', 8192]]},
      {syscall => 'pipe2', },
    ],
  },

  # perl module specific
  perlmod_file_temp => {
    rules => [
      {syscall => 'chmod', rules => [[1, '==', 0600]]},
      {syscall => 'unlink', },
      ],
  },

  # exec wrapper
  exec_wrapper => {
    # we have to generate these at runtime, we can't know ahead of time what they will be
    rules => sub {
        my $seccomp = shift;
        my $strptr = sub {unpack "Q", pack("p", $_[0])};
        my @rules;

        my $exec_map = $seccomp->exec_map;

        for my $version (keys %$exec_map) {
          push @rules, {syscall => 'execve', rules => [[0, '==', $strptr->($exec_map->{$version}{bin})]]};
        }

        return \@rules;
      }, # sub returns a valid arrayref.  given our $self as first arg.
  },

  # language master rules
  lang_perl => {
    rules => [],
    include => ['default'],
  },

  lang_ruby => {
    rules => [
      # Thread IPC writes, these might not be fixed but I don't know how to detect them otherwise 
      {syscall => 'write', rules => [[0, '==', 5]]},
      {syscall => 'write', rules => [[0, '==', 7]]},
    ],
    include => ['default', 'ruby_timer_thread'],
  },
};

sub rule_add {
  my ($self, $name, @rules) = @_;

  $self->seccomp->rule_add(SCMP_ACT_ALLOW, Linux::Seccomp::syscall_resolve_name($name), @rules);
}

sub _rec_get_rules {
  my ($self, $profile, $used_sets) = @_;

  croak "Rule set $profile not found" unless exists $rule_sets{$profile};

  for my $rules (@{$rule_sets{$profile}}) {
  }
}

sub build_seccomp {
  my ($self) = @_;

  my %used_sets = (); # keep track of which sets we've seen so we don't include multiple times

  my %comp_rules; # computed rules

  for my $profile (@{$self->profiles}) {
    next if ($used_sets{$profile});
    $used_sets{$profile} = 1;
    
    my @rules = $self->_rec_get_rules($profile, \%used_sets);
    print Dumper({profile => $profile, rules=>\@rules});
  }
}

# sub get_seccomp {
#     my $lang = shift;
# 
# 
#     
# 
#     # this annoying bitch of code is because Algorithm::Permute doesn't work with newer perls
#     # Also this ends up more efficient.  We skip 0 because it's redundant
#     for my $b (1..(2**@allowed_open_modes) - 1) {
#       my $q = 1;
#       my $mode = 0;
#       #printf "%04b: ", $b;
#       do {
#         if ($q & $b) {
#           my $r = int(log($q)/log(2)+0.5); # get the thing
# 
#           $mode |= $allowed_open_modes[$r];
# 
#           #print "$r";
#         }
#         $q <<= 1;
#       } while ($q <= $b);
# 
#       $rule_add->(open => [1, '==', $mode]);
#       $rule_add->(openat => [2, '==', $mode]);
#       #print " => $mode\n";
#     }
# 
# 
# 
# 
# 
#     $seccomp->load unless -e './noseccomp';
# }
1;
