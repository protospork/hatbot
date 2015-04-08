#TODO:
#port database to SQL
#find a nick that doesn't blow
#
#all hats spent on fedoras go into community bank. every 24hr, bank is either:
##given to someone 
##spent entirely on fedoras for the person who gave the most

# <sugoidesune> I really need to figure out some sort of endgame for the hat economy
# <@BoarderX> hatpocalypse?
# <General_Vagueness> The Hatpenning
# <sugoidesune> think I'll leave .hat as is but remove the constant arson
# <sugoidesune> and do something to make gambling an actual system
# <sugoidesune> wanna go all in on hats
# <sugoidesune> double or nothing
# <sugoidesune> also need a way to convince #moap that fedoras are a bad thing

# <@sugoidesune> oh man I could tie the odds on the hat gambling to a person's enlightenment score

# <sugoidesune> if I'm tying odds to fedoras I guess I should do the random bronies thing after all


use vars qw($VERSION %IRSSI);
use Modern::Perl;
use Tie::YAML;

$VERSION = "2.1.4";
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

	$server->command("action $target $return");
}
sub give_hats {
	my $them = lc $_[0];
	my $hats = 1;
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
			my $no = pluralize('thinks '.$_[0].' should be content with '.$hats{$them}{'hats'}.' hat');
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
		$out = pluralize('gives '.$hats.' hat');
		$out =~ s/\.$//; #already misusing my own functions. cool.
		$out .= pluralize(' to '.$_[0].' for a total of '.$new_hats.' hat');
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

	my $price;
	if ($hats{lc $top}{'hats'} < 10){
		return "demands at least ten hats for this service.";
	}
	$price = int($hats{lc $top}{'hats'} / 10);
	$price = 10 if $price < 10;

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
sub pluralize {
	my $string = $_[0];
	my $num = ($string =~ /(\d+)/)[-1];

	$num != 1 # why does this work...
		? $string .= 's'
		: $string .= '.';
	# if ($num == 0 || $num > 1){
	# 	$string .= 's';
	# }
	# $string .= '.';

	return $string;
}
sub bank {
	if (! exists $hats{'BANK'}{'hats'}){
		$hats{'BANK'}{'hats'} = 0;
		tied(%hats)->save;
	}
	return (pluralize("currently holds ".$hats{'BANK'}{'hats'}." hat"), $hats{"BANK"}{'hats'});
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

		$return = pluralize('transfers '.$bet.' hat');
		$return =~ s/\.$//;
		$return .= pluralize(' to '.$nick.'. Hatbot retains '.$hats{'BANK'}{'hats'}.' hat');
	} else { #house wins
		$hats{lc $nick}{'hats'} -= $bet;
		$hats{'BANK'}{'hats'} += $bet;

		tied(%hats)->save;

		$return = pluralize('takes '.$bet.' hat');
		$return =~ s/\.$//;
		$return .= pluralize(' from '.$nick.'. Hatbot now holds '.$hats{'BANK'}{'hats'}.' hat');
	}
	return $return;
}

Irssi::signal_add("event privmsg", "event_privmsg");
Irssi::command_bind("hat_party", \&reset_times);