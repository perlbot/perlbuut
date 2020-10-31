use Module::ScanDeps;
use Data::Dumper;

my @files = ('./bin/cpan_fetch.pl', './bin/generate_metaphones.pl', './bin/test_eval.pl', './asndb/mkasn.pl', './plugins/head.pm', './plugins/echo.pm', './plugins/packages.pm', './plugins/translate.pm', './plugins/save_config.pm', './plugins/nick_lookup.pm', './plugins/tell.pm', './plugins/conf.pm', './plugins/oeis.pm', './plugins/reload_plugins.pm', './plugins/seen.pm', './plugins/part.pm', './plugins/utf8.pm', './plugins/cache_check.pm', './plugins/title.pm', './plugins/geoip.pm', './plugins/twitter.pm', './plugins/8ball.pm', './plugins/conf_dump.pm', './plugins/unicode.pm', './plugins/shorten.pm', './plugins/karma.pm', './plugins/join.pm', './plugins/perldoc.pm', './plugins/allowpaste.pm', './plugins/help.pm', './plugins/rss_title.pm', './plugins/get.pm', './plugins/plugins.pm', './plugins/define.pm', './plugins/default.pm', './plugins/host.pm', './plugins/arg.pm', './plugins/quote.pm', './plugins/pastebinadmin.pm', './plugins/null.pm', './plugins/host_lookup.pm', './plugins/zippit.pm', './plugins/talktome.pm', './plugins/factoids.pm', './plugins/karma_modify.pm', './plugins/google.pm', './plugins/compose.pm', './plugins/more.pm', './plugins/core.pm', './plugins/chatbot.pm', './plugins/rss.pm', './plugins/supereval.pm', './plugins/restart.pm', './plugins/karmatop.pm', './package_lists/generate_list_debian.pl', './lib/Bot/BB3.pm', './lib/Bot/BB3/Logger.pm', './lib/Bot/BB3/PluginManager.pm', './lib/Bot/BB3/ConfigParser.pm', './lib/Bot/BB3/DebugCrypt.pm', './lib/Bot/BB3/MacroQuote.pm', './lib/Bot/BB3/Roles/Console.pm', './lib/Bot/BB3/Roles/RestAPI.pm', './lib/Bot/BB3/Roles/Evalpastebin.pm', './lib/Bot/BB3/Roles/SocketMessageIRC.pm', './lib/Bot/BB3/Roles/IRC.pm', './lib/Bot/BB3/Roles/PasteBot.pm', './lib/Bot/BB3/PluginConfigParser.pm', './lib/Bot/BB3/PluginWrapper.pm');

my $hash_ref = scan_deps(
  #  files => \@files,
  files => ["plugins/geoip.pm"],
  recurse => 0,
);

my @keys = keys %$hash_ref;

my @used = sort {$a cmp $b} grep {!m|Bot/BB3|} grep {exists $hash_ref->{$_}{used_by} } @keys;

my @mods = map {s|/|::|g; s|.pm$||r} @used;

#print Dumper(\@mods);

for my $mod (@mods) {
  printf "requires '%s';\n", $mod;
}
