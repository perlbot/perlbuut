use strict;
use warnings;

use Data::Dumper;
use JSON;
use Paws;
use Paws::Credential::Explicit;

my $creds = Paws::Credential::Explicit->new(access_key => '', secret_key => '');
my $paws = Paws->new(config => {credentials => $creds, region => 'us-east-1'});
my $cognito = $paws->service("CognitoIdentity");
my $pool_id = 'us-east-1:dbe1d89b-d4ed-459d-ba40-ef8f096b5e4b';
my $ident_id = $cognito->GetId(IdentityPoolId => $pool_id)->IdentityId;

#print Dumper($ident_id);

my $cresp = $cognito->GetCredentialsForIdentity(IdentityId => $ident_id)->Credentials;
my $realcreds = Paws::Credential::Explicit->new(access_key=>$cresp->AccessKeyId, secret_key=>$cresp->SecretKey, session_token=>$cresp->SessionToken);

my $service_obj = $paws->service('LexRuntime', credentials => $realcreds, region=>'us-east-1');


return sub {
	my( $said ) = @_;

  my $body = $said->{body};
  my $userid = $said->{server}.$said->{channel}.$said->{nick};
  $userid =~ s/\W/_/g; # hide any non word chars

  my $resp = $service_obj->PostText(BotName=>'BookTrip', BotAlias=>'perlbot',InputText=>$body,UserId=>$userid);

  use JSON::MaybeXS;
  my $json = JSON->new();
  printf "%s : %s\n", $resp->Message, $json->encode(\%{$resp->Slots->Map});
};


__END__
__DATA__
chatbot <text> - Screw around with simcop2387's Amazon lex project
