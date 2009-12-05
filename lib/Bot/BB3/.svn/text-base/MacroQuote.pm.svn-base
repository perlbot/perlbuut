# This package defines the quoting methods common between the
# quote and arg plugins.
package Bot::BB3::MacroQuote;
sub quote {
	my($m,$s) = @_;
	if ("z" eq $m) { # no-op
		return $s;
	} elsif ("c" eq $m || "d" eq $m) { # c-like quoting (without or with double-quote delimiter)
		$s =~ s/([\x00\x01\n\r\x10\"\#\$\'\@\\])/sprintf"\\x%02x",ord$1/ge;
		return "d" eq $m ? qq["$s"] : $s;
	} elsif ("e" eq $m || "f" eq $m) { # quote almost everything
		$s =~ s/(\W)/sprintf"\\x%02x",ord$1/ge;
		return "f" eq $m ? qq["$s"] : $s;
	} elsif ("h" eq $m) { # pack byte to two hex digits each, if nothing else this must work
		return unpack "H*", $s;
	} else { # unknown quoting mode
		return $s;
	}
}
1;
