#!/usr/bin/env perl

#use lib '/home/ryan/perl5/lib/perl5/i686-linux';
#use lib '/home/ryan/perl5/lib/perl5';

use strict;
use Data::Dumper;
use Scalar::Util; #Required by Data::Dumper
use BSD::Resource;
use File::Glob;
use POSIX;
use List::Util qw/reduce/;
use Cwd;
use FindBin;

# Modules expected by many evals, load them now to avoid typing in channel
use Encode qw/encode decode/;
use IO::String;
use File::Slurper qw/read_text/;

# Easter eggs
do {package Tony::Robbins; sub import {die "Tony Robbins hungry: https://www.youtube.com/watch?v=GZXp7r_PP-w\n"}; $INC{"Tony/Robbins.pm"}=1};
do {package Zathras; our $AUTOLOAD; sub AUTOLOAD {$AUTOLOAD=~s/.*:://; "Everybody come to Zathras for '$AUTOLOAD'.  Zathras not mind.";}};

# save the old stdout, we're going to clobber it soon. STDOUT
my $oldout;
my $outbuffer = "";
open($oldout, ">&STDOUT") or die "Can't dup STDOUT: $!";
open(my $stdh, ">", \$outbuffer)
               or die "Can't dup to buffer: $!";
select($stdh);
$|++;
#*STDOUT = $stdh;

sub get_seccomp {
    use Linux::Seccomp ':all';
    my $seccomp = Linux::Seccomp->new(SCMP_ACT_KILL);
    ##### set seccomp
    #
    # Rules should only allow:
    # 1. open as read
    # 2. write to stderr/stdout
    # 3. exit
    # 4. close file handle
    # 5. random syscall
    # 6. read
    # 7. seek
# 8. fstat/fcntl
# 9. brk
# 10.

    my $rule_add = sub {
        my $name = shift;
        $seccomp->rule_add(SCMP_ACT_ALLOW, syscall_resolve_name($name), @_);
    };

    $rule_add->(write => [0, '==', 2]); # STDERR
    $rule_add->(write => [0, '==', 1]); # STDOUT

    #mmap(NULL, 2112544, PROT_READ|PROT_EXEC, MAP_PRIVATE|MAP_DENYWRITE, 7, 0) = 0x7efedad0e000
    #mprotect(0x7efedad12000, 2093056, PROT_NONE) = 0
    #mmap(0x7efedaf11000, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_FIXED|MAP_DENYWRITE, 7, 0x3000) = 0x7efedaf11000
    ## MMAP? I don't know what it's being used for exactly.  I'll leave it out and see what happens
    # Used when loading executable code.  Might need to figure out what to do to make it more secure?
    # also seems to be used when freeing/allocating large blocks of memory, as you'd expect
    $rule_add->(mmap => );
    $rule_add->(munmap => );
    $rule_add->(mremap => );
    $rule_add->(mprotect =>);

    # Allow select, might need to have some kind of restriction on it?  probably fine
    $rule_add->(select => );

    # These are the allowed modes on open, allow that to work in any combo
    my ($O_DIRECTORY, $O_CLOEXEC, $O_NOCTTY) = (00200000, 02000000, 00000400);
    my @allowed_open_modes = (&POSIX::O_RDONLY, &POSIX::O_NONBLOCK, $O_DIRECTORY, $O_CLOEXEC, $O_NOCTTY);

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

    my @blind_syscalls = qw/read exit exit_group brk lseek fstat fcntl stat rt_sigaction rt_sigprocmask geteuid getuid getcwd close getdents getgid getegid getgroups lstat nanosleep getrlimit/;

    for my $syscall (@blind_syscalls) {
        $rule_add->($syscall);
    }

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
	    	$sub = eval "use $]; sub{ $code\n }";
        }
		if( $@ ) { print STDOUT "Error: $@"; return }

		my $dp = B::Deparse->new("-p", "-q", "-x7");
		my $ret = $dp->coderef2text($sub);

			$ret =~ s/\{//;
			$ret =~ s/package (?:\w+(?:::)?)+;//;
			$ret =~ s/ no warnings;//;
			$ret =~ s/\s+/ /g;
			$ret =~ s/\s*\}\s*$//;
            $ret =~ s/\s*\$\^H\{[^}]+\}(\s+=\s+[^;]+;?)?\s*//g;
            $ret =~ s/\s*BEGIN\s*\{\s*[^}]*\s*\}\s*/ /;

		print STDOUT $ret;
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

	my $code = do { local $/; <STDIN> };

	# Close every other filehandle we may have open
	# this is probably legacy code at this point since it was used
	# inside the original bb2 which forked to execute this code.
	opendir my $dh, "/proc/self/fd" or die $!;
	while(my $fd = readdir($dh)) { next unless $fd > 2; POSIX::close($fd) }

	# Get the nobody uid before we chroot.
	my $nobody_uid = getpwnam("nobody");
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
	chdir($FindBin::Bin."/../jail") or die "Jail not made, see bin/makejail.sh";

    # redirect STDIN to /dev/null, to avoid warnings in convoluted cases.
    open STDIN, '<', '/dev/null' or die "Can't open /dev/null: $!";

	chroot(".") or die $!;

# 	# Here's where we actually drop our root privilege
# 	$)="$nobody_uid $nobody_uid";
# 	$(=$nobody_uid;
# 	$<=$>=$nobody_uid;
# 	POSIX::setgid($nobody_uid); #We just assume the uid is the same as the gid. Hot.


	die "Failed to drop to nobody"
		if $> != $nobody_uid
		or $< != $nobody_uid;

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
	setrlimit(RLIMIT_NPROC, 1,1)
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
get_seccomp();

	$code =~ s/^\s*(\w+)\s*//
		or die "Failed to parse code type! $code";
	my $type = $1;

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
#	elsif( $type eq 'javascript' ) {
#		javascript_code($code);
#	}
#	elsif( $type eq 'php' ) {
#		php_code($code);
#	}
#	elsif( $type eq 'k20' ) {
#		k20_code($code);
#	}
#	elsif( $type eq 'rb' or $type eq 'ruby' ) {
#		ruby_code($code);
#	}
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
        local $$=24601;
        close STDIN;
        my $stdin = q{Biqsip bo'degh cha'par hu jev lev lir loghqam lotlhmoq nay' petaq qaryoq qeylis qul tuq qaq roswi' say'qu'moh tangqa' targh tiq 'ab. Chegh chevwi' tlhoy' da'vi' ghet ghuy'cha' jaghla' mevyap mu'qad ves naq pach qew qul tuq rach tagh tal tey'. Denibya' dugh ghaytanha' homwi' huchqed mara marwi' namtun qevas qay' tiqnagh lemdu' veqlargh 'em 'e'mam 'orghenya' rojmab. Baqa' chuy da'nal dilyum ghitlhwi' ghubdaq ghuy' hong boq chuydah hutvagh jorneb law' mil nadqa'ghach pujwi' qa'ri' ting toq yem yur yuvtlhe' 'e'mamnal 'iqnah qad 'orghenya' rojmab 'orghengan. Beb biqsip 'ugh denibya' ghal ghobchuq lodni'pu' ghochwi' huh jij lol nanwi' ngech pujwi' qawhaq qeng qo'qad qovpatlh ron ros say'qu'moh soq tugh tlhej tlhot verengan ha'dibah waqboch 'er'in 'irneh.
Cha'par denib qatlh denibya' ghiq jim megh'an nahjej naq nay' podmoh qanwi' qevas qin rilwi' ros sila' tey'lod tus vad vay' vem'eq yas cha'dich 'entepray' 'irnehnal 'urwi'. Baqa' be'joy' bi'res chegh chob'a' dah hos chohwi' piq pivlob qa'ri' qa'rol qewwi' qo'qad qi'tu' qu'vatlh say'qu'moh sa'hut sosbor'a' tlhach mu'mey vid'ir yas cha'dich yergho. Chegh denibya'ngan jajvam jij jim lev lo'lahbe'ghach ngun nguq pa' beb pivlob pujwi' qab qid sosbor'a' tlhepqe' tlhov va 'o'megh 'ud haqtaj. Bor cha'nas denibya' qatlh duran lung dir ghogh habli' homwi' hoq je' notqa' pegh per pitlh qarghan qawhaq qen red tey'lod valqis vid'ir wab yer yintagh 'edjen. Bi'rel tlharghduj cheb ghal lorlod ne' ngij pipyus pivlob qutluch red sila' tuqnigh.
Chob'a' choq chuq'a' dol jev jij lev marwi' mojaq ngij ngugh pujmoh puqni'be' qaywi' qirq qi'yah qum taq tey'be' tlhup valqis 'edsehcha. Chadvay' cha'par ghal je' lir lolchu' lursa' maqmigh ngun per qen qevas quv bey' soq targh tiq tlhot veqlargh wen. Baqa' chuq'a' jev juch logh lol lor mistaq nahjej nuh bey' nguq pujmoh qovpatlh ron tahqeq tuy' vithay' yo'seh yahniv yuqjijdivi' 'em 'orghenya'ngan. Beb cheb chob da'nal da'vi' ghoti' ghuy'cha' hoq loghqam ngav po ha'dibah qen qo'qad qid ril siq tuy' tlhoy' sas vinpu' wab yuqjijqa' 'em 'o'megh. Bachha' biq boqha''egh cheb dor duran lung dir ghang hos chohwi' je' luh mu'qad ves nav habli' qab qan rach siqwi' tennus tepqengwi' tuqnigh tlhoy' sas va vin yeq yuqjijdivi' 'ab 'edjen 'iqnah 'ud'a' 'urwi'.
Baqa' bi'res boq'egh da'vi' dol dor ghet ghetwi' ghogh habli' hos chohwi' nga'chuq petaq pirmus puqni' qutluch qaj qid qi'tu' qongdaqdaq siq tahqeq ti'ang toq tlhup yatqap yer 'ur. Biqsip 'ugh chang'eng choq choq hutvagh jajlo' qa' jer nanwi' nav habli' pirmus qab qa'meh vittlhegh qa'ri' sen siv vem'eq yer yo'seh yahniv yuqjijdivi' 'arlogh 'e'mamnal 'och. Chang'eng chas cha'dich choq lursa' mil natlh nay' puqni'be' qeng qid qulpa' ret sa'hut viq wen yiq yuqjijdivi' yu'egh 'edsehcha 'entepray' 'er'in 'ev 'irneh 'iw 'ip ghomey 'orwi' 'ud haqtaj 'usgheb. Chadvay' gheb lol lorbe' lursa' pivlob qep'it sen senwi' rilwi' je tajvaj wogh. Chevwi' tlhoy' huh lol lorbe' neslo' ne' pipyus qaq qi'yah tal 'ev.
Biqsip biqsip 'ugh chan ghitlh lursa' nuh bey' ngun petaq qeng soj tlhej waqboch 'ab 'entepray' 'e'mam. Bo denibya' ghetwi' ghochwi' ghuy' ghuy'cha' holqed huh jaj je' matlh pegh petaq qawhaq qa'meh qay' tagh tey' wogh yer yu'egh 'orghen 'urwi'. Boq'egh choq dav jim laq nga'chuq ngoqde' ngusdi' qan qu'vatlh sen tijwi'ghom ti'ang wogh 'orghenya'ngan. Biq cha'nas chegh chob dilyum ghetwi' juch me'nal motlh po ha'dibah puqni'lod qab qarghan qaywi' qaj rutlh say'qu'moh todsah tus yas wa'dich 'aqtu' 'edjen 'e'nal 'orwi'. Bor chob jaghla' je' jorneb mellota' meqba' nguq rachwi' ron tey' tiqnagh lemdu' vay' 'usgheb. Bis'ub cheb chob'a' dugh homwi' lotlhmoq mu'qad ves nahjej nanwi' naw' nitebha' ngoqde' ngusdi' pach pujmoh puqni'lod qan qay' rech senwi' tangqa' tepqengwi' tlhej tlhot valqis waqboch 'aqtu' 'e'mam 'iqnah 'orghen rojmab.};
        open(STDIN, "<", \$stdin);

		local $_;

        my $ret;

        my @os = qw/aix bsdos darwin dynixptx freebsd haiku linux hpux irix next openbsd dec_osf svr4 sco_sv unicos unicosmk solaris sunos MSWin32 MSWin16 MSWin63 dos os2 cygwin VMS vos os390 os400 posix-bc riscos amigaos xenix/;

        {
        local $^O = $os[rand()*@os];
        no strict; no warnings; package main;
#        my $oldout;
		$code = "use $]; use feature qw/postderef refaliasing lexical_subs postderef_qq signatures/; use experimental 'declared_refs';\n#line 1\n$code";
		$ret = eval $code;
        }
        select STDOUT;

		local $Data::Dumper::Terse = 1;
		local $Data::Dumper::Quotekeys = 0;
		local $Data::Dumper::Indent = 0;
		local $Data::Dumper::Useqq = 1;

		my $out = ref($ret) ? Dumper( $ret ) : "" . $ret;

		print $out unless $outbuffer;

		if( $@ ) { print "ERROR: $@" }
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
