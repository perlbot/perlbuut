package EvalServer::Seccomp;

use strict;
use warnings;

use Data::Dumper;
use List::Util qw/reduce/;
use Moo;
use Sys::Linux::Unshare qw/:consts/;
use POSIX;
use Linux::Seccomp;

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

# Define some more open modes that POSIX doesn't have for us.
my ($O_DIRECTORY, $O_CLOEXEC, $O_NOCTTY, $O_NOFOLLOW) = (00200000, 02000000, 00000400, 00400000);

    my @blind_syscalls = qw/rt_sigaction rt_sigprocmask geteuid getuid getcwd close getdents getgid getegid getgroups lstat nanosleep getrlimit clock_gettime clock_getres/;

my %rule_sets = {
  default => {
    include => ['time_calls', 'file_readonly', 'stdio'],
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
              {syscall => 'fcntl'},
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
    permute => {open_modes => [&POSIX::O_NONBLOCK, &POSIX::O_EXCL, &POSIX::O_RDONLY, $O_NOFOLLOW, $O_CLOEXC]},
    include => ['file_open'],
  },
  file_write => {
    permute => {open_modes => [&POSIX::O_CREAT,&POSIX::O_WRONLY, &POSIX::O_TRUNC, &POSIX::O_RDWR]},
    rules => [{syscall => 'write'}],
    include => ['file_open', 'file_readonly'],
  },

  # time related stuff
  time_calls => {
    rules => [],
  },

  # ruby timer threads
  ruby_timer_thread => {
#    permute => {clone_flags => []},
    rules => [
      {syscall => clone, rules => [[0, '==', CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND|CLONE_THREAD|CLONE_SYSVSEM|CLONE_SETTLS|CLONE_PARENT_SETTID|CLONE_CHILD_CLEARTID]]},

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
  }

  # exec wrapper
  exec_wrapper => {
    rules => sub {...}, # sub returns a valid arrayref.  given our $self as first arg.
    # # Enable us to run other perl binaries
    # for my $version (keys %exec_map) {
    #   $rule_add->(execve => [0, '==', $strptr->($exec_map{$version}{bin})]);
    # }
  },

  # language master rules
  lang_perl => {
    rules => [],
    include => ['default'],
  },

  lang_ruby => {
    rules => [
      # Thread IPC writes, these might not be fixed but I don't know how to detect them otherwise 
      {syscall => write, rules => [[0, '==', 5]]},
      {syscall => write, rules => [[0, '==', 7]]},
    ],
    include => ['default', 'ruby_timer_thread'],
  },
}

sub engage_seccomp {
  my ($self) = @_;
    
  my $seccomp = Linux::Seccomp->new(SCMP_ACT_KILL);

  my $rule_add = sub {
    my $name = shift;
    $seccomp->rule_add(SCMP_ACT_ALLOW, Linux::Seccomp::syscall_resolve_name($name), @_);
  };
}

sub get_seccomp {
    my $lang = shift;

    my $strptr = sub {unpack "Q", pack("p", $_[0])};

    $rule_add->(access => );
    $rule_add->(arch_prctl => );
    $rule_add->(readlink => );
    $rule_add->(getpid => );
    
    $rule_add->(set_tid_address => ); # needed for perl >= 5.20
    $rule_add->(set_robust_list => );
    $rule_add->(futex => );

    # this annoying bitch of code is because Algorithm::Permute doesn't work with newer perls
    # Also this ends up more efficient.  We skip 0 because it's redundant
    for my $b (1..(2**@allowed_open_modes) - 1) {
      my $q = 1;
      my $mode = 0;
      #printf "%04b: ", $b;
      do {
        if ($q & $b) {
          my $r = int(log($q)/log(2)+0.5); # get the thing

          $mode |= $allowed_open_modes[$r];

          #print "$r";
        }
        $q <<= 1;
      } while ($q <= $b);

      $rule_add->(open => [1, '==', $mode]);
      $rule_add->(openat => [2, '==', $mode]);
      #print " => $mode\n";
    }

    # 4352  ioctl(4, TCGETS, 0x7ffd10963820)  = -1 ENOTTY (Inappropriate ioctl for device)
    $rule_add->(ioctl => [1, '==', 0x5401]); # This happens on opened files for some reason? wtf




    $seccomp->load unless -e './noseccomp';
}

no warnings;

# This sub is defined here so that it is defined before the 'use charnames'
# command. This causes extremely strange interactions that result in the
# deparse output being much longer than it should be.
	sub deparse_perl_code {
		my( $code ) = @_;
      my $sub;
      {
          no strict; no warnings; no charnames;
          $sub = eval "use $]; package botdeparse; sub{ $code\n }";
      }

      my %methods = (map {$_ => botdeparse->can($_)} grep {botdeparse->can($_)} keys {%botdeparse::}->%*);

      if( $@ ) { print STDOUT "Error: $@"; return }

      my $dp = B::Deparse->new("-p", "-q", "-x7", "-d");
      local *B::Deparse::declare_hints = sub { '' };
      my @out;

      my $clean_out = sub {
        my $ret = shift;
        $ret =~ s/\{//;
        $ret =~ s/package (?:\w+(?:::)?)+;//;
        $ret =~ s/no warnings;//;
        $ret =~ s/\s+/ /g;
        $ret =~ s/\s*\}\s*$//;
        $ret =~ s/no feature ':all';//;
        $ret =~ s/use feature [^;]+;//;
        $ret =~ s/^\(\)//g;
        $ret =~ s/^\s+|\s+$//g;
        return $ret;
      };

      for my $sub (keys %methods) {
        my $ret = $clean_out->($dp->coderef2text($methods{$sub}));

        push @out, "sub $sub {$ret} ";
      }
      
      my $ret = $dp->coderef2text($sub);
      $ret = $clean_out->($ret);
      push @out, $ret;

      my $fullout = join(' ', @out);

       use Perl::Tidy; 
       my $hide = do {package hiderr; sub print{}; bless {}}; 
       my $tidy_out="";
       eval {
         my $foo = "$fullout";
         Perl::Tidy::perltidy(source => \$foo, destination => \$tidy_out, errorfile => $hide, logfile => $hide);
       };

      $tidy_out = $fullout if ($@);

      print STDOUT $tidy_out;
	}

eval "use utf8; \$\343\201\257 = 42; 'ש' =~ /([\p{Bidi_Class:L}\p{Bidi_Class:R}])/";  # attempt to automatically load the utf8 libraries.
eval "use utf8; [ 'ß' =~ m/^\Qss\E\z/i ? 'True' : 'False' ];"; # Try to grab some more utf8 libs
eval "use utf8; [CORE::fc '€']";
use charnames qw(:full);
use PerlIO;
use PerlIO::scalar;
use Text::ParseWords;

eval {"\N{SPARKLE}"}; # force loading of some of the charnames stuff

# Required for perl_deparse
use B::Deparse;

## Javascript Libs
#BEGIN{ eval "use JavaScript::V8; require JSON::XS; JavaScript::V8::Context->new()->eval('1')"; }
#my $JSENV_CODE = do { local $/; open my $fh, "deps/env.js"; <$fh> };
#require 'bytes_heavy.pl';

use Tie::Hash::NamedCapture;

 {#no warnings 'constant';
 uc "\x{666}"; #Attempt to load unicode libraries.
 lc "JONQUIÉRE";
 }
 binmode STDOUT, ":encoding(utf8)"; # Enable utf8 output.

#BEGIN{ eval "use PHP::Interpreter;"; }

# Evil Ruby stuff
#BEGIN{ eval "use Inline::Ruby qw/rb_eval/;"; }
#BEGIN { $SIG{SEGV} = sub { die "Segmentation Fault\n"; } } #Attempt to override the handler Ruby installs.

# # Evil K20 stuff
# BEGIN {
# 	local $@;
# 	eval "use Language::K20;";
# 	unless( $@ ) {
# 		Language::K20::k20eval( "2+2\n" ); # This eval loads the dynamic components before the chroot.
#                                    # Note that k20eval always tries to output to stdout so we
#                                    # must end the command with a \n to prevent this output.
# 	}
# }
#
# BEGIN { chdir "var/"; $0="../$0"; } # CHDIR to stop inline from creating stupid _Inline directories everywhere
# # Inline::Lua doesn't seem to provide an eval function. SIGH.
# BEGIN { eval 'use Inline Lua => "function lua_eval(str) return loadstring(str) end";'; }
# BEGIN { chdir ".."; $0=~s/^\.\.\/// } # Assume our earlier chdir succeded. Yay!


# # Evil python stuff
# BEGIN { eval "use Inline::Python qw/py_eval/;"; }

# # Evil J stuff
# BEGIN { eval "use Jplugin;"; }

use Carp::Heavy;
use Storable qw/nfreeze/; nfreeze([]); #Preload Nfreeze since it's loaded on demand

	my $type = do { local $/=" ";

    # have to do this with sysread in order to keep it from destroying STDIN for exec later.

    my $q;
    my $c;

    while (sysread STDIN, $c, 1) {
      $q .= $c;
      last if $c eq $/;
    }

    chomp $q; $q 
  };
  
  my $code = do {local $/; <STDIN>};
  # redirect STDIN to /dev/null, to avoid warnings in convoluted cases.
  # we have to leave this open for perl4, so only do this for other systems
  open STDIN, '<', '/dev/null' or die "Can't open /dev/null: $!";

	# Get the nobody uid before we chroot.
	my $nobody_uid = 65534; #getpwnam("nobody");
	die "Error, can't find a uid for 'nobody'. Replace with someone who exists" unless $nobody_uid;

	# Set the CPU LIMIT.
	# Do this before the chroot because some of the other
	# setrlimit calls will prevent chroot from working
	# however at the same time we need to preload an autload file
	# that chroot will prevent, so do it here.
	setrlimit(RLIMIT_CPU, 10,10);

# 	# Root Check
# 	if( $< != 0 )
# 	{
# 		die "Not root, can't chroot or take other precautions, dying\n";
# 	}

	# The chroot section
  chdir("/eval") or die $!;

  # It's now safe for us to do this so that we can load modules and files provided by the user
  push @INC, "/eval/lib";

  if ($< == 0) {
      # Here's where we actually drop our root privilege
      $)="$nobody_uid $nobody_uid";
      $(=$nobody_uid;
      $<=$>=$nobody_uid;
      POSIX::setgid($nobody_uid); #We just assume the uid is the same as the gid. Hot.


      die "Failed to drop to nobody"
          if $> != $nobody_uid
          or $< != $nobody_uid;
  }

	my $kilo = 1024;
	my $meg = $kilo * $kilo;
	my $limit = 300 * $meg;

	(
	setrlimit(RLIMIT_VMEM, 1.5*$limit, 1.5*$limit)
		and
	setrlimit(RLIMIT_DATA, $limit, $limit )
		and
	setrlimit(RLIMIT_STACK, $limit, $limit )
		and
	setrlimit(RLIMIT_NPROC, 4,4) # CHANGED to 3 for Ruby.  Might take it away.
		and
	setrlimit(RLIMIT_NOFILE, 20,20)
		and
	setrlimit(RLIMIT_OFILE, 20,20)
		and
	setrlimit(RLIMIT_OPEN_MAX,20,20)
		and
	setrlimit(RLIMIT_LOCKS, 0,0)
		and
	setrlimit(RLIMIT_AS,$limit,$limit)
		and
	setrlimit(RLIMIT_MEMLOCK,100,100)
		and
	setrlimit(RLIMIT_CPU, 10, 10)
	)
		or die "Failed to set rlimit: $!";

  %ENV=(TZ=>'Asia/Pyongyang');
	#setrlimit(RLIMIT_MSGQUEUE,100,100);

	die "Failed to drop root: $<" if $< == 0;
	# close STDIN;

  # Setup SECCOMP for us
  get_seccomp($type);
	# Chomp code..
	$code =~ s/\s*$//;

	# Choose which type of evaluation to perform
	# will probably be a dispatch table soon.
	if( $type eq 'perl' or $type eq 'pl' ) {
		perl_code($code);
	}
	elsif( $type eq 'deparse' ) {
		deparse_perl_code($code);
	}
  elsif ($type =~ /perl([0-9.]+)/) { # run specific perl version
    perl_version_code($1, $code);
  }
#	elsif( $type eq 'javascript' ) {
#		javascript_code($code);
#	}
#	elsif( $type eq 'php' ) {
#		php_code($code);
#	}
#	elsif( $type eq 'k20' ) {
#		k20_code($code);
#	}
	elsif( $type eq 'ruby' ) {
		ruby_code($code);
	}
#	elsif( $type eq 'py' or $type eq 'python' ) {
#		python_code($code);
#	}
#	elsif( $type eq 'lua' ) {
#		lua_code($code);
#	}
#	elsif( $type eq 'j' ) {
#		j_code($code);
#	}

#        *STDOUT = $oldout;
        close($stdh);
        select(STDOUT);
        print($outbuffer);

	exit;

	#-----------------------------------------------------------------------------
	# Evaluate the actual code
	#-----------------------------------------------------------------------------
	sub perl_code {
		my( $code ) = @_;
		local $@;
		local @INC = map {s|/home/ryan||r} @INC;
#        local $$=24601;
        close STDIN;
        my $stdin = q{Biqsip bo'degh cha'par hu jev lev lir loghqam lotlhmoq nay' petaq qaryoq qeylis qul tuq qaq roswi' say'qu'moh tangqa' targh tiq 'ab. Chegh chevwi' tlhoy' da'vi' ghet ghuy'cha' jaghla' mevyap mu'qad ves naq pach qew qul tuq rach tagh tal tey'. Denibya' dugh ghaytanha' homwi' huchqed mara marwi' namtun qevas qay' tiqnagh lemdu' veqlargh 'em 'e'mam 'orghenya' rojmab. Baqa' chuy da'nal dilyum ghitlhwi' ghubdaq ghuy' hong boq chuydah hutvagh jorneb law' mil nadqa'ghach pujwi' qa'ri' ting toq yem yur yuvtlhe' 'e'mamnal 'iqnah qad 'orghenya' rojmab 'orghengan. Beb biqsip 'ugh denibya' ghal ghobchuq lodni'pu' ghochwi' huh jij lol nanwi' ngech pujwi' qawhaq qeng qo'qad qovpatlh ron ros say'qu'moh soq tugh tlhej tlhot verengan ha'dibah waqboch 'er'in 'irneh.
Cha'par denib qatlh denibya' ghiq jim megh'an nahjej naq nay' podmoh qanwi' qevas qin rilwi' ros sila' tey'lod tus vad vay' vem'eq yas cha'dich 'entepray' 'irnehnal 'urwi'. Baqa' be'joy' bi'res chegh chob'a' dah hos chohwi' piq pivlob qa'ri' qa'rol qewwi' qo'qad qi'tu' qu'vatlh say'qu'moh sa'hut sosbor'a' tlhach mu'mey vid'ir yas cha'dich yergho. Chegh denibya'ngan jajvam jij jim lev lo'lahbe'ghach ngun nguq pa' beb pivlob pujwi' qab qid sosbor'a' tlhepqe' tlhov va 'o'megh 'ud haqtaj. Bor cha'nas denibya' qatlh duran lung dir ghogh habli' homwi' hoq je' notqa' pegh per pitlh qarghan qawhaq qen red tey'lod valqis vid'ir wab yer yintagh 'edjen. Bi'rel tlharghduj cheb ghal lorlod ne' ngij pipyus pivlob qutluch red sila' tuqnigh.
Chob'a' choq chuq'a' dol jev jij lev marwi' mojaq ngij ngugh pujmoh puqni'be' qaywi' qirq qi'yah qum taq tey'be' tlhup valqis 'edsehcha. Chadvay' cha'par ghal je' lir lolchu' lursa' maqmigh ngun per qen qevas quv bey' soq targh tiq tlhot veqlargh wen. Baqa' chuq'a' jev juch logh lol lor mistaq nahjej nuh bey' nguq pujmoh qovpatlh ron tahqeq tuy' vithay' yo'seh yahniv yuqjijdivi' 'em 'orghenya'ngan. Beb cheb chob da'nal da'vi' ghoti' ghuy'cha' hoq loghqam ngav po ha'dibah qen qo'qad qid ril siq tuy' tlhoy' sas vinpu' wab yuqjijqa' 'em 'o'megh. Bachha' biq boqha''egh cheb dor duran lung dir ghang hos chohwi' je' luh mu'qad ves nav habli' qab qan rach siqwi' tennus tepqengwi' tuqnigh tlhoy' sas va vin yeq yuqjijdivi' 'ab 'edjen 'iqnah 'ud'a' 'urwi'.
Baqa' bi'res boq'egh da'vi' dol dor ghet ghetwi' ghogh habli' hos chohwi' nga'chuq petaq pirmus puqni' qutluch qaj qid qi'tu' qongdaqdaq siq tahqeq ti'ang toq tlhup yatqap yer 'ur. Biqsip 'ugh chang'eng choq choq hutvagh jajlo' qa' jer nanwi' nav habli' pirmus qab qa'meh vittlhegh qa'ri' sen siv vem'eq yer yo'seh yahniv yuqjijdivi' 'arlogh 'e'mamnal 'och. Chang'eng chas cha'dich choq lursa' mil natlh nay' puqni'be' qeng qid qulpa' ret sa'hut viq wen yiq yuqjijdivi' yu'egh 'edsehcha 'entepray' 'er'in 'ev 'irneh 'iw 'ip ghomey 'orwi' 'ud haqtaj 'usgheb. Chadvay' gheb lol lorbe' lursa' pivlob qep'it sen senwi' rilwi' je tajvaj wogh. Chevwi' tlhoy' huh lol lorbe' neslo' ne' pipyus qaq qi'yah tal 'ev.
Biqsip biqsip 'ugh chan ghitlh lursa' nuh bey' ngun petaq qeng soj tlhej waqboch 'ab 'entepray' 'e'mam. Bo denibya' ghetwi' ghochwi' ghuy' ghuy'cha' holqed huh jaj je' matlh pegh petaq qawhaq qa'meh qay' tagh tey' wogh yer yu'egh 'orghen 'urwi'. Boq'egh choq dav jim laq nga'chuq ngoqde' ngusdi' qan qu'vatlh sen tijwi'ghom ti'ang wogh 'orghenya'ngan. Biq cha'nas chegh chob dilyum ghetwi' juch me'nal motlh po ha'dibah puqni'lod qab qarghan qaywi' qaj rutlh say'qu'moh todsah tus yas wa'dich 'aqtu' 'edjen 'e'nal 'orwi'. Bor chob jaghla' je' jorneb mellota' meqba' nguq rachwi' ron tey' tiqnagh lemdu' vay' 'usgheb. Bis'ub cheb chob'a' dugh homwi' lotlhmoq mu'qad ves nahjej nanwi' naw' nitebha' ngoqde' ngusdi' pach pujmoh puqni'lod qan qay' rech senwi' tangqa' tepqengwi' tlhej tlhot valqis waqboch 'aqtu' 'e'mam 'iqnah 'orghen rojmab.};
        open(STDIN, "<", \$stdin);

		local $_;

        my $ret;

        my @os = qw/aix bsdos darwin dynixptx freebsd haiku linux hpux irix next openbsd dec_osf svr4 sco_sv unicos unicosmk solaris sunos MSWin32 MSWin16 MSWin63 dos os2 cygwin vos os390 os400 posix-bc riscos amigaos xenix/;

        {
#          local $^O = $os[rand()*@os];
          no strict; no warnings; package main;
#        my $oldout;
          do {
            local $/="\n";
            local $\;
            local $,;
            $code = "use $]; use feature qw/postderef refaliasing lexical_subs postderef_qq signatures/; use experimental 'declared_refs';\n#line 1 \"(IRC)\"\n$code";
            $ret = eval $code;
          }
        }
        select STDOUT;

		local $Data::Dumper::Terse = 1;
		local $Data::Dumper::Quotekeys = 0;
		local $Data::Dumper::Indent = 0;
		local $Data::Dumper::Useqq = 1;
        local $Data::Dumper::Freezer = "dd_freeze";

		my $out = ref($ret) ? Dumper( $ret ) : "" . $ret;

		print $out unless $outbuffer;

		if( $@ ) { print "ERROR: $@" }
	}

  sub perl_version_code {
    my ($version, $code) = @_;

    my $qcode = quotemeta $code;

    my $wrapper = 'use Data::Dumper; 
    
		local $Data::Dumper::Terse = 1;
		local $Data::Dumper::Quotekeys = 0;
		local $Data::Dumper::Indent = 0;
		local $Data::Dumper::Useqq = 1;

    my $val = eval "#line 1 \"(IRC)\"\n'.$qcode.'";

    if ($@) {
      print $@;
    } else {
      $val = ref($val) ? Dumper ($val) : "".$val;
      print " ",$val;
    }
    ';

    unless ($version eq '4') {
      exec($exec_map{'perl'.$version}{bin}, '-e', $wrapper) or die "Exec failed $!";
    } else {
      exec($exec_map{'perl'.$version}{bin}, '-e', $code); # the code for perl4 is actually still in STDIN, if we try to -e it needs to write files
    }
  }
  
  sub ruby_code {
    my ($code) = @_;

    exec($exec_map{'ruby'}{bin}, '-e', $code);
  }

# 	sub javascript_code {
# 		my( $code ) = @_;
# 		local $@;
#
# 		my $js = JavaScript::V8::Context->new;
#
# 		# Set up the Environment for ENVJS
# 		$js->bind("print", sub { print @_ } );
# 		$js->bind("write", sub { print @_ } );
#
# #		for( qw/log debug info warn error/ ) {
# #			$js->eval("Envjs.$_=function(x){}");
# #		}
#
# #		$js->eval($JSENV_CODE) or die $@;
#
#                 $code =~ s/(["\\])/\\$1/g;
#                 my $rcode = qq{write(eval("$code"))};
#
#
#
# 		my $out = eval { $js->eval($rcode) };
#
# 		if( $@ ) { print "ERROR: $@"; }
#                 else { print encode_json $out }
# 	}
#
# 	sub ruby_code {
# 		my( $code ) = @_;
# 		local $@;
#
# 		print rb_eval( $code );
# 	}
#
# 	sub php_code {
# 		my( $code ) = @_;
# 		local $@;
#
# 		#warn "PHP - [$code]";
#
# 		my $php = PHP::Interpreter->new;
#
# 		$php->set_output_handler(\ my $output );
#
# 		$php->eval("$code;");
#
# 		print $php->get_output;
#
# 		#warn "ENDING";
#
# 		if( $@ ) { print "ERROR: $@"; }
# 	}
#
# 	sub k20_code {
# 		my( $code ) = @_;
#
# 		$code =~ s/\r?\n//g;
#
#
# 		Language::K20::k20eval( '."\\\\r ' . int(rand(2**31)) . '";' . "\n"); # set random seed
#
# 		Language::K20::k20eval(	$code );
# 	}
#
# 	sub python_code {
# 		my( $code ) = @_;
#
# 		py_eval( $code, 2 );
# 	}
#
# 	sub lua_code {
# 		my( $code ) = @_;
#
# 		#print lua_eval( $code )->();
#
# 		my $ret = lua_eval( $code );
#
# 		print ref $ret ? $ret->() : $ret;
# 	}
#
# 	sub j_code {
# 		my( $code ) = @_;
#
# 		Jplugin::jplugin( $code );
# 	}
