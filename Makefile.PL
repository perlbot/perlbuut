#!env perl

use strict;  
use warnings;

use inc::Module::Install;

name "Buubot";
version 0.1;
#all_from       'lib/Bot/BB3.pm';

requires  'POE' => 0;
requires  'Parse::RecDescent' => 0;
requires  'Config::General' => 0;
requires  'Cache::FastMmap' => 0;
requires  'POE::Component::IRC::Common' => 0;
requires  'POE::Component::IRC' => 0;

requires 'Geo::IP' => 0;
requires 'XML::RSS::Parser' => 0;
requires 'WWW::Shorten' => 0;
requires 'WWW::Mechanize' => 0;
requires 'URI::Encode' => 0;
requires 'Text::Glob' => 0;

requires 'DBD::SQLite' => 0;
requires 'DBI' => 0;
requires 'Net::DNS' => 0;
requires 'HTML::TreeBuilder' => 0;
requires 'Net::INET6Glue::INET_is_INET6' => 0;

requires 'Net::Dict' => 0;
requires 'HTML::TreeBuilder::XPath' => 0;

requires 'Data::Dumper' => 0;
requires 'Scalar::Util' => 0; #Required by Data::Dumper
requires 'BSD::Resource' => 0;
requires 'File::Glob' => 0;
requires 'POSIX' => 0;

requires 'List::Util' => 0;
requires 'List::MoreUtils' => 0;
requires 'List::UtilsBy' => 0;
requires 'Data::Munge' => 0;
requires 'Scalar::MoreUtils' => 0;
requires 'Regexp::Common' => 0;
requires 'Encode' => 0;
requires 'Digest::MD5' => 0;
requires 'Digest::SHA' => 0;
requires 'DateTime' => 0;
requires 'DateTimeX::Easy' => 0;
requires 'Date::Parse' => 0;

requires 'Moose' => 0;
requires 'MooseX::Declare' => 0;

requires 'Function::Parameters' => 0;

WriteAll;
