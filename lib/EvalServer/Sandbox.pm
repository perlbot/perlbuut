package EvalServer::Sandbox;

use strict;
use warnings;

use Config;
use Sys::Linux::Namespace;
use Sys::Linux::Mount qw/:all/;
my %sig_map;
use FindBin;

do {
  my @sig_names = split ' ', $Config{sig_name}; 
  my @sig_nums = split ' ', $Config{sig_num}; 
  @sig_map{@sig_nums} = map {'SIG' . $_} @sig_names;
  $sig_map{31} = "SIGSYS (Illegal Syscall)";
};

my $namespace = Sys::Linux::Namespace->new(private_pid => 1, no_proc => 1, private_mount => 1, private_uts => 1,  private_ipc => 0, private_sysvsem => 1);

# {files => [
#      {filename => '...',
#       contents => '...',},
#       ...,],
#  main_file => 'filename',
#  main_language => '',
# }
#

sub run_eval {
  my $code = shift; # TODO this should be more than just code
  my $jail_path = $FindBin::Bin."/../jail";
  my $jail_root_path = $FindBin::Bin."/../jail_root";

	my $filename = '/eval/elib/eval.pl';

  $namespace->run(code => sub {
    my @binds = (
      {src => $jail_root_path,    target => "/"},
      {src => "/lib64",     target => "/lib64"},
      {src => "/lib",             target => "/lib"},
      {src => "/usr/lib",         target => "/usr/lib"},
      {src => "/usr/bin",         target => "/usr/bin"},
      {src => "/home/ryan/perl5", target => "/perl5"},
      {src => "/home/ryan/perl5", target => "/home/ryan/perl5"},
      {src => $FindBin::Bin."/../lib", target => "/eval/elib"},
      {src => $FindBin::Bin."/../langs", target => "/langs"},
    );

    for my $bind (@binds) {
      mount($bind->{src}, $jail_path . $bind->{target}, undef, MS_BIND|MS_PRIVATE|MS_RDONLY, undef);
    }

    mount("tmpfs", $FindBin::Bin."/../jail/tmp", "tmpfs", 0, {size => "16m"});
    mount("tmpfs", $FindBin::Bin."/../jail/tmp", "tmpfs", MS_PRIVATE, {size => "16m"});

    chdir($jail_path) or die "Jail not made, see bin/makejail.sh";
    chroot($jail_path) or die $!;

    
    #system("/perl5/perlbrew/perls/perlbot-inuse/bin/perl", $filename); 
    system($^X, $filename); 
    my ($exit, $signal) = (($?&0xFF00)>>8, $?&0xFF);

    if ($exit) {
     print "[Exited $exit]";
    } elsif ($signal) {
     my $signame = $sig_map{$signal} // $signal;
     print "[Died $signame]";
    }
  });
}

1;
