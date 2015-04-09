#TODO:
#port database to SQL
#find a nick that doesn't blow
#

# <sugoidesune> if I'm tying odds to fedoras I guess I should do the random bronies thing after all

use vars qw($VERSION %IRSSI);
use Modern::Perl;
use Tie::YAML;

$VERSION = "2.2.3";
%IRSSI = (
    authors => 'protospork',
    contact => 'https://github.com/protospork',
    name => 'hats',
    description => 'a dumb game/societal worth calculator',
    license => 'MIT/X11'
);
Irssi::settings_add_str('hatbot', 'hat_channels', '#wat');
Irssi::settings_add_str('hatbot', 'hat_lords', "");
Irssi::settings_add_int('hatbot', 'hat_timeout', 86400);
Irssi::settings_add_int('hatbot', 'hat_fedora_price', 50);


tie my %hats, 'Tie::YAML', $ENV{HOME}.'/.irssi/scripts/cfg/hats.po' or die $!;

sub event_privmsg {
	my ($server, $data, $nick, $mask) = @_;
	my ($target, $text) = split(/ :/, $data, 2);
	my $return;

	my @enabled_chans = split /,/, Irssi::settings_get_str('hat_channels');
	my $hat_lords = Irssi::settings_get_str('hat_lords');

	return unless grep lc $target eq lc $_, (@enabled_chans);

	#how many hoops would I need to jump through to get switch statements back
	if ($text =~ /^\s*\.hats?\b/i){
		if ($text =~ /party/){
			my $pretender = (split /\@/, $mask)[-1];
			if ($hat_lords =~ /$pretender/i){
				reset_times();
				$return = 'obeys.';
			}
		} else {
			$return = (give_hats($nick))[0];
		}
	} elsif ($text =~ /^\s*\.fedora (\w+)/i){
		$return = fedoras($nick, $1);
	} elsif ($text =~ /^\s*\.enl(?:ighten(?:ment)?)? (\w+)/i){
		$return = (score($1))[0];

	} elsif ($text =~ /^\s*\.bank/i){
		$return = (bank())[0];
	} elsif ($text =~ s/^\s*\.bet//i){
		$return = gamble($text, $nick);
	} else {
		return;
	}

	$return = pluralize($return);
	$server->command("action $target $return");
}
sub give_hats {
	my $them = lc $_[0];
	my $hats = 6;
	$hats += int(rand(5));

	my $bonus;

	my $past_hats = 0;
	if (exists $hats{$them}{'hats'}){
		$past_hats = $hats{$them}{'hats'};
	} else {
		$hats{$them}{'hats'} = 0;
	}

	my $hat_timeout = Irssi::settings_get_int('hat_timeout');

	if (exists $hats{$them}{'last_time'}){
		if (time - $hats{$them}{'last_time'} < $hat_timeout){

			# <~sugoidesune> maybe instead of globally boosting the drop rate I could just throw a few extra from hatbot's own stash at the poorer players
			# <BoarderX> lol welfare hats
			if ($hats{'BANK'}{'hats'} > 1000 && $hats{$them}{'hats'} < 10){
				#initialize some stuff just to be safe
				if (! exists $hats{$them}{'last_handout'}){
					$hats{$them}{'last_handout'} = 0;
				}
				if (! exists $hats{$them}{'fedoras'}){
					$hats{$them}{'fedoras'} = 0;
				}

				# make fedoras affect the payout
				my $gift = 50 - $hats{$them}{'fedoras'};
				# only one welfare payout per 24h
				if (time - $hats{$them}{'last_handout'} > 86400 && $gift > 0){
					$hats{$them}{'last_handout'} = time;

					$hats{$them}{'hats'} += $gift;
					$hats{'BANK'}{'hats'} -= $gift;
					tied(%hats)->save;

					my $out = 'is giving you '.$gift.' hats from his personal fund, '.$_[0].'. Please try to get your life back on track.';
					return $out;
				}
			}
			my $no = ('thinks '.$_[0].' should be content with '.$hats{$them}{'hats'}.' hats.');
			return $no;
		}
	} else {
		$hats{$them}{'last_time'} = 0;
	}

	$hats{$them}{'last_time'} = time;
	
	my $new_hats = $hats + $past_hats;

	if (int(rand(100)) > 95){
		$new_hats = $past_hats + 111;
		$bonus = 'has a sticky keyboard, resulting in 111 hats for '.$_[0].'!';
	}

	$hats{$them}{'hats'} = $new_hats;

	tied(%hats)->save;

	my $out;
	if ($bonus){
		$out = $bonus;
	} else {
		$out = 'gives '.$hats.' hats to '.$_[0].' for a total of '.$new_hats.' hats.';
	}
	return ($out, $hats, $new_hats);
}
sub fedoras {
	my ($top, $bottom) = @_;

	if (! exists $hats{lc $bottom}){ #there are many saner ways to validate a nick <_<
		return "does not think $bottom is a person.";
	} elsif (! $bottom) {
		return "needs a target.";
	}

	my $price = Irssi::settings_get_int('hat_fedora_price');
	if ($hats{lc $top}{'hats'} < $price){
		return "demands at least $price hats for this service.";
	}
	$hats{lc $top}{'hats'} -= $price;
	$hats{lc $bottom}{'fedoras'} += 1;

	$hats{'BANK'}{'hats'} += $price;

	tied(%hats)->save;

	return 'takes '.$price.' of '.$top.'\'s hats and raises '.$bottom.'\'s enlightenment to '.(score($bottom))[-1];
}
sub reset_times {
	for (keys %hats){
		$hats{$_}{'last_time'} = 8;

		tied(%hats)->save;
	}
	print "hat timeouts (probably) reset";
}
sub score {
	my ($good, $bad);
	if (exists $hats{lc $_[0]}{'hats'}){
		$good = $hats{lc $_[0]}{'hats'};
	} else {
		return ('does not pick on children.', 0);
	}
	if (exists $hats{lc $_[0]}{'fedoras'}){
		$bad = $hats{lc $_[0]}{'fedoras'};
	} else {
		$bad = 0;
	}
	$bad *= 10;

	my $score = 0;
	if ($bad > 0){
		$score = sprintf "%.03f", (10000 / ((($good + $bad) / $bad) * 200));
		return ("estimates ".$_[0]."'s enlightenment to be ".$score.".", $score);
	} else {
		return ("refuses to stoop to your level.", 0);
	}

}
sub pluralize { #always refer to "hats", never "hat"
	my $string = $_[0];
	$string =~ s/\b1 ([Hh])ats/1 $1at/gi;

	return $string;
}
sub bank {
	if (! exists $hats{'BANK'}{'hats'}){
		$hats{'BANK'}{'hats'} = 0;
		tied(%hats)->save;
	}
	return ("currently holds ".$hats{'BANK'}{'hats'}." hats.", $hats{"BANK"}{'hats'});
}
sub gamble {
	my ($text, $nick) = @_;

	my $custom = 0;

	my $bet = $hats{lc $nick}{'hats'};
	if ($text =~ /(\d+)/){ #default bet is everything but you can be a babby if you want
		if ($1 < $bet){
			$bet = $1;
		} elsif ($1 > $bet){ # don't try to bet more than you have
			return "is not stupid. You only have $bet hats.";
		}
		$custom++;
	}

	my $max_bet = $hats{'BANK'}{'hats'};
	if ($bet > $max_bet){
		if ($max_bet == 0){
			return "is broke.";
		} elsif ($custom){
			return "can only match up to ".$max_bet.".";
		} else {
			$bet = $max_bet;
		}
	} elsif ($bet == 0){
		return "will not give you something for nothing.";
	}

	# adjust odds based on person's fedoras
	my $odds = 100;
	my $win; 
	if (exists $hats{lc $nick}{'fedoras'}){
		$odds -= $hats{lc $nick}{'fedoras'};
	}
	$win = int rand $odds;
	if ($win >= 50){
		$win = 1;
	} else {
		$win = 0;
	}

	my $return;
	if ($win){ #they win
		$hats{lc $nick}{'hats'} += $bet;
		$hats{'BANK'}{'hats'} -= $bet;

		tied(%hats)->save;

		$return = 'raises '.$nick.'\'s balance to '.$hats{lc $nick}{'hats'}.' hats. Hatbot retains '.$hats{'BANK'}{'hats'}.' hats.';
	} else { #house wins
		$hats{lc $nick}{'hats'} -= $bet;
		$hats{'BANK'}{'hats'} += $bet;

		tied(%hats)->save;

		$return = 'lowers '.$nick.'\'s balance to '.$hats{lc $nick}{'hats'}.' hats. Hatbot now holds '.$hats{'BANK'}{'hats'}.' hats.';
	}
	return $return;
}

Irssi::signal_add("event privmsg", "event_privmsg");
Irssi::command_bind("hat_party", \&reset_times);