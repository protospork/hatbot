# player can spend 10 banked hats to give a fedora to someone (fedoras are bad)
# fedoras are permanent? random fedora theft incidents? bronies?


#TODO: (in order of importance)
#fedoras
#port database to SQL
#find a nick that doesn't blow
#uhh does perl have a problem with huge numbers?

use vars qw($VERSION %IRSSI);
use Modern::Perl;
use Tie::YAML;

$VERSION = "0.2.5";
%IRSSI = (
    authors => 'protospork',
    contact => 'https://github.com/protospork',
    name => 'hats',
    description => 'a dumb game(?)',
    license => 'MIT/X11'
);
Irssi::settings_add_str('hatbot', 'hat_channels', '#wat');



tie my %hats, 'Tie::YAML', $ENV{HOME}.'/.irssi/scripts/cfg/hats.po' or die $!;

sub event_privmsg {
	my ($server, $data, $nick, $mask) = @_;
	my ($target, $text) = split(/ :/, $data, 2);

	my @enabled_chans = split /,/, Irssi::settings_get_str('hat_channels');
	return unless grep lc $target eq lc $_, (@enabled_chans);

	if ($text =~ /^\s*\.hats?$/i){
		#continue
	} elsif ($text =~ /^\s*\.fedora$/i){
		return; #for now
	} else {
		return;
	}

	my $return = (give_hats($nick))[0];
	$server->command("action $target $return");
}
sub give_hats {
	my $hats = 1;
	$hats += int(rand(5));
	my $bonus;

	my $past_hats = 0;
	if (exists $hats{$_[0]}{'hats'}){
		$past_hats = $hats{$_[0]}{'hats'};
	} else {
		$hats{$_[0]}{'hats'} = 0;
	}


	if (exists $hats{$_[0]}{'last_time'}){
		if (time - $hats{$_[0]}{'last_time'} < 86400){
			my $no = pluralize('thinks '.$_[0].' should be content with '.$hats{$_[0]}{'hats'}.' hat');
			return $no;
		}
	} else {
		$hats{$_[0]}{'last_time'} = 0;
	}

	$hats{$_[0]}{'last_time'} = time;
	
	my $new_hats = $hats + $past_hats;

	if (int(rand(100)) > 90){
		if (time % 2){
			$new_hats = 1;
			$bonus = 'burns down '.$_[0].'\'s house, destroying all the hats inside.';
		} else {
			$new_hats = $past_hats + 111;
			$bonus = 'has a sticky keyboard, resulting in 111 hats for '.$_[0].'!';
		}
	}
	$hats{$_[0]}{'hats'} = $new_hats;

	tied(%hats)->save;

	my $out;
	if ($bonus){
		$out = $bonus;
	} else {
		$out = pluralize('gives '.$hats.' hat');
		$out =~ s/\.$//; #already misusing my own functions. cool.
		$out .= pluralize(' to '.$_[0].' for a total of '.$new_hats.' hat');
	}
	return ($out, $hats, $new_hats);
}
sub reset_times {
	for (keys %hats){
		$hats{$_}{'last_time'} = 8;

		tied(%hats)->save;
	}
	print "hat timeouts (probably) reset";
}
sub pluralize {
	my $string = $_[0];
	my $num = ($string =~ /(\d+)/)[-1];

	$num > 1 # why does this work...
	? $string .= 's'
	: $string .= '.';

	return $string;
}

Irssi::signal_add("event privmsg", "event_privmsg");
Irssi::command_bind("hat_party", \&reset_times);