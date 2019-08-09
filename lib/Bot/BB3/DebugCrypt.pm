package Bot::BB3::DebugCrypt;
use CryptX;
use Crypt::Mode::CBC;
use MIME::Base64;
use Path::Tiny;
use strict;
use warnings;

use Exporter qw/import/;
our @EXPORT=qw/encrypt decrypt/;

my $key = pack("H*", path('etc/crypt.key')->slurp_utf8 =~ s/\s//gr);
my $iv = 'TOTALLYSECURE!!!';

sub encrypt {
  my $data = shift;
  $data = pack("N", rand(2**32)) . $data;
  my $cipher = Crypt::Mode::CBC->new('AES');
  return MIME::Base64::encode($cipher->encrypt($data, $key, $iv));
}

sub decrypt {
  my $data = MIME::Base64::decode(shift);
  my $cipher = Crypt::Mode::CBC->new('AES');
  my $plain = $cipher->decrypt($data, $key, $iv);
  $plain = substr($plain, 4);
  return $plain
}

1;
