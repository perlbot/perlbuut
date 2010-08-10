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

WriteAll;
