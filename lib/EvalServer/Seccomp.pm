package EvalServer::Seccomp;

use strict;
use warnings;

use Data::Dumper;
use List::Util qw/reduce uniq/;
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
has _permutes => (is => 'ro', default => sub {+{}});
has _used_sets => (is => 'ro', default => sub {+{}});

has _finalized => (is => 'rw', default => 0); # TODO make this set once

# Define some more open modes that POSIX doesn't have for us.
my ($O_DIRECTORY, $O_CLOEXEC, $O_NOCTTY, $O_NOFOLLOW) = (00200000, 02000000, 00000400, 00400000);

# TODO this needs some accessors to make it easier to define rulesets
our %rule_sets = (
  default => {
    include => ['time_calls', 'file_readonly', 'stdio', 'exec_wrapper', 'file_write', 'file_tty'],
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

  perm_test => {
    permute => {foo => [1, 2, 3], bar => [4, 5, 6]},
    rules => [{syscall => 'permme', permute_rules => [[0, '==', \'foo'], [1, '==', \'bar']]}]
  },

  # File related stuff
  stdio => {
    rules => [{syscall => 'read', rules => [[qw|0 == 0|]]},  # STDIN
              {syscall => 'write', rules => [[qw|0 == 1|]]}, # STDOUT
              {syscall => 'write', rules => [[qw|0 == 2|]]},
              ],
  },
  file_open => {
    rules => [{syscall => 'open',   permute_rules => [['1', '==', \'open_modes']]}, 
              {syscall => 'openat', permute_rules => [['2', '==', \'open_modes']]},
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

        return @rules;
      }, # sub returns a valid arrayref.  given our $self as first arg.
  },

  # language master rules
  lang_perl => {
    rules => [],
    include => ['default', 'perlmod_file_temp'],
  },

  lang_ruby => {
    rules => [
      # Thread IPC writes, these might not be fixed but I don't know how to detect them otherwise 
      {syscall => 'write', rules => [[0, '==', 5]]},
      {syscall => 'write', rules => [[0, '==', 7]]},
    ],
    include => ['default', 'ruby_timer_thread'],
  },
);

sub rule_add {
  my ($self, $name, @rules) = @_;

  $self->seccomp->rule_add(SCMP_ACT_ALLOW, Linux::Seccomp::syscall_resolve_name($name), @rules);
}

sub _process_rule {
  my ($self, $rule) = @_;
}

sub _rec_get_rules {
  my ($self, $profile) = @_;

  return () if ($self->_used_sets->{$profile});
  $self->_used_sets->{$profile} = 1;

  croak "Rule set $profile not found" unless exists $rule_sets{$profile};

  my @rules;
  #print "getting profile $profile\n";

  if (ref $rule_sets{$profile}{rules} eq 'ARRAY') {
    push @rules, @{$rule_sets{$profile}{rules}};
  } elsif (ref $rule_sets{$profile}{rules} eq 'CODE') {
    my @sub_rules = $rule_sets{$profile}{rules}->($self);
    push @rules, @sub_rules;
  } elsif (!exists $rule_sets{$profile}{rules}) { # ignore it if missing
  } else {
    croak "Rule set $profile defines an invalid set of rules";
  }
  
  for my $perm (keys %{$rule_sets{$profile}{permute} // +{}}) {
    push @{$self->_permutes->{$perm}}, @{$rule_sets{$profile}{permute}{$perm}};
  }

  for my $include (@{$rule_sets{$profile}{include}//[]}) {
    push @rules, $self->_rec_get_rules($include);
  }

  return @rules;
}

sub build_seccomp {
  my ($self) = @_;

  my %gathered_rules; # computed rules

  for my $profile (@{$self->profiles}) {
    my @rules = $self->_rec_get_rules($profile);

    for my $rule (@rules) {
      my $syscall = $rule->{syscall};
      push @{$gathered_rules{$syscall}}, $rule;
    }
  }

  # optimize phase
  my %full_permute;
  for my $permute (keys %{$self->_permutes}) {
    my @modes = @{$self->_permutes->{$permute}} = sort {$a <=> $b} uniq @{$self->_permutes->{$permute}};

    # Produce every bitpattern for this permutation
    for my $b (1..(2**@modes) - 1) {
      my $q = 1;
      my $mode = 0;
      #printf "%04b: ", $b;
      do {
        if ($q & $b) {
          my $r = int(log($q)/log(2)+0.5); # get the thing

          $mode |= $modes[$r];

          #print "$r";
        }
        $q <<= 1;
      } while ($q <= $b);

      push @{$full_permute{$permute}}, $mode;
    }
  }

  for my $k (keys %full_permute) {
  @{$full_permute{$k}} = sort {$a <=> $b} uniq @{$full_permute{$k}} 
  }

  # TODO optimize for permissive rules
  # e.g. write => OR write => [0, '==', 1] OR write => [0, '==', 2] becomes write =>


  my %comp_rules;

  for my $syscall (keys %gathered_rules) {
    my @rules = @{$gathered_rules{$syscall}};
    for my $rule (@rules) {
      print Dumper($rule);
      my $syscall = $rule->{syscall};

      if (exists ($rule->{permute_rules})) {
        my @perm_on = ();
        for my $prule (@{$rule->{permute_rules}}) {
          if (ref $prule->[2]) {
            push @perm_on, ${$prule->[2]};
          }
          if (ref $prule->[0]) {
            croak "Permuation on argument number not supported using $syscall";
          }
        }

        croak "Permutation on syscall rule without actual permutation specified" if (!@perm_on);

        my $glob_string = join '__', map { "{".join(",", @{$full_permute{$_}})."}" } @perm_on;
        for my $g_value (glob $glob_string) {
          my %pvals;
          @pvals{@perm_on} = split /__/, $g_value;


          push @{$comp_rules{$syscall}}, 
            [map {
              my @r = @$_;
              $r[2] = $pvals{${$r[2]}};
              \@r;
            } @{$rule->{permute_rules}}];
        }
      } elsif (exists ($rule->{rules})) {
        push @{$comp_rules{$syscall}}, $rule->{rules};
      } else {
        push @{$comp_rules{$syscall}}, [];
      }
    }
  }

  print Dumper({comp_rules=>\%comp_rules, used_sets => $self->_used_sets, permutes => $self->_permutes});
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
