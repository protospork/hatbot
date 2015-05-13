#TODO:
#port database to SQL

# also prob raise fedora price depending on your fedoras

# if you wanna get fancy make the antiflood detect repeated triggers / outputs and only clam up for those

# <@penguins> hatbot should start charging people a fee for fedora maintenance

# <@BEES> I feel like I should set up some sort of global odds boost centered around fedoraing hatbot, but also I have no idea how that would work
# <@Tar> for betting
# <@Tar> fedoras affect people the current way
# <@Tar> but hatbot also has odds that are affected by fedoras on a smaller scale
# <%Lucifer7> 1 fedora on hatbot equals a .25% boost to everyone's chances
# <@Tar> higher roll wins
# <@Tar> oh and fedoras clear out fairly frequent (but potentially randomly so it's not gameable?)
# <@BEES> hatbot's would have to roll off either on a timer or whenever he wins a bet, since doesn't have free will like bawk
# <+bawk> hatbot's too poor or duct-taping-things-to-shotguns poor
# <@Tar> it'd be when people bet against him
# <Jason> how about whoever has a number of fedoras closer to the modulo of hatbot's total fedoras?
# <@Tar> like ".bet 10" roll 2 die and higher wins

#GIFTING:
#-format should be gift $amount $nick so it's harder to trick spaghettio
#-don't allow new nicks to gift hats (but it should be fine for them to receive hats?)
#-they can only send one gift per 24h?
#-they can't send gifts within 24 of getting charity?

#HATSTATS:
#dump raw transaction info into #hatmarket or generate a rawlog I can dump into /www or something, I don't know
#maybe don't do this until SQL happens?

use vars qw($VERSION %IRSSI);
use Modern::Perl;
use Tie::YAML;

$VERSION = "2.10.1";
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
Irssi::settings_add_int('hatbot', 'hat_bet_timeout', 3);
Irssi::settings_add_bool('hatbot', 'hat_debug_mode', 1);
Irssi::settings_add_bool('hatbot', 'hat_fiat_hats', 1);


tie my %hats, 'Tie::YAML', $ENV{HOME}.'/.irssi/scripts/cfg/hats.po' or die $!;
if (! $hats{'BANK'}{'lotto_last'}){
	$hats{'BANK'}{'lotto_last'} = (gmtime)[2];
}
my $debug_mode = Irssi::settings_get_bool('hat_debug_mode');
my $hat_creation = Irssi::settings_get_bool('hat_fiat_hats');
my $already_poor = 0;

sub event_privmsg {
	my ($server, $data, $nick, $mask) = @_;
	my ($target, $text) = split(/ :/, $data, 2);
	my $return;

	my @enabled_chans = split /,/, Irssi::settings_get_str('hat_channels');
	my $hat_lords = Irssi::settings_get_str('hat_lords');

	return unless grep lc $target eq lc $_, (@enabled_chans);

	#antiflood thing
	if (! exists $hats{lc $nick}{'last_trigger'}){
		$hats{lc $nick}{'last_trigger'} = time - 10;
	}

	#how many hoops would I need to jump through to get switch statements back
	if ($text =~ /^\s*\.hats?\b/i){
		if ($text =~ /\bparty\b/i){
			my $pretender = (split /\@/, $mask)[-1];
			if ($hat_lords =~ /$pretender/i){
				reset_times();
				$return = 'obeys.';
			}
		} elsif ($text =~ /\bcheck\b/i){
			$return = (give_hats($nick, 1))[0];
		} else {
			$return = (give_hats($nick, 0))[0];
		}
	} elsif ($text =~ /^\s*\.fedora/i){
		$return = fedoras($nick, $text);
	} elsif ($text =~ /^\s*\.enl(?:ighten(?:ment)?)? (\w+)/i){
		$return = (score($1))[0];
	} elsif ($text =~ /^\s*\.enl/i){ #elegant.
		$return = (score($nick))[0];
	} elsif ($text =~ /^\s*\.bank/i){
		$return = (bank())[0];
	} elsif ($text =~ s/^\s*\.bet//i){
		$return = gamble($text, $nick);
	} elsif ((gmtime)[2] != $hats{'BANK'}{'lotto_last'}){
		($return, $target) = lottery($target);
	} elsif ($text =~ /^\s*\.lotto/i){ # manually trigger lotteries for testing
		my $pretender = (split /\@/, $mask)[-1];
		if ($hat_lords =~ /$pretender/i){
			($return, $target) = lottery($target);
		} else {
			return;
		}
	} elsif ($hats{'BANK'}{'hats'} == 0){
		$return = go_bankrupt();
	} else {
		return;
	}

	#if it got this far it probably is a trigger
	$hats{lc $nick}{'last_trigger'} = time;
	$hats{lc $nick}{'last_chan'} = $target;

	$return = pluralize($return);
	if ($return && $return ne 'STOP'){
		$server->command("action $target $return");
	}
}
sub give_hats {
	my $them = lc $_[0];
	my $hats = 36;
	my $bonus;

	my $safe = $_[1];

	my $past_hats = 0;
	if (exists $hats{$them}{'hats'}){
		$past_hats = $hats{$them}{'hats'};
	} else {
		$hats{$them}{'hats'} = 0;
	}

	#initialize the anti-flood thing here for some reason
	if (! exists $hats{$them}{'flood'}){
		$hats{$them}{'flood'} = 0;
	}

	my $hat_timeout = Irssi::settings_get_int('hat_timeout');

	if (exists $hats{$them}{'last_time'}){ 
		if (time - $hats{$them}{'last_time'} < $hat_timeout){
			$hats = (time - $hats{$them}{'last_time'});
			$hats = int($hats / 300); 
			# 300secs = 5min. add one hat per 5min
			# that's 12 hats per hour, but
			# if they manage 3 hours (36 hats),
			# use hatbot's wallet to
			# boost it to 50 (later)
			if ($hats >= 36){
				$hats = 36;
			}


			# <~sugoidesune> maybe instead of globally boosting the drop rate I could just throw a few extra from hatbot's own stash at the poorer players
			# <BoarderX> lol welfare hats
			if ($hats < 1 && $hats{'BANK'}{'hats'} > 2000 && $hats{$them}{'hats'} < 10){
				#initialize some stuff just to be safe
				if (! exists $hats{$them}{'last_handout'}){
					$hats{$them}{'last_handout'} = 0;
				}
				if (! exists $hats{$them}{'fedoras'}){
					$hats{$them}{'fedoras'} = 0;
				}

				# make fedoras affect the payout
				my $gift = 100 - (2 * $hats{$them}{'fedoras'});
				if ($hat_creation){
					# only one welfare payout per 24h
					if (time - $hats{$them}{'last_handout'} > 86400 && $gift > 0){
						$hats{$them}{'last_handout'} = time;

						$hats{$them}{'hats'} += $gift;
						$hats{'BANK'}{'hats'} -= $gift;
						tied(%hats)->save;

						my $out = 'is giving you '.$gift.' hats from his personal fund, '.$_[0].'. Please try to get your life back on track.';
						return $out;
					}
				} else { #if everything's coming out of hatbot's pocket, be more stingy
					$gift = 0;
				}
			}

			my $no;
			if ($hats == 0){
				if (! $safe){
				#punish them for their impatience
					$no = ('thinks '.$_[0].' should be content with '.$hats{$them}{'hats'}.' hats.');

					$hats{$them}{'last_time'} += 600;
				} else {
					$no = hat_check($_[0]);
				}

				$hats{$them}{'flood'}++;

				tied(%hats)->save;

				if ($hats{$them}{'flood'} > 1 && time - $hats{$them}{'last_trigger'} < 2){
					return 'STOP';
				}
				return $no;
			}
		}
	} else {
		$hats{$them}{'last_time'} = 0;
		$hats = 36;
	}

	if ($hats < 36 && $safe){
		return hat_check($_[0]);
	} elsif ($hats == 36 && $hats{'BANK'}{'hats'} > 14){
		$hats{'BANK'}{'hats'} -= 14;
		$hats = 50;
	}


	$hats{$them}{'flood'} = 0;
	
	my $new_hats = $hats + $past_hats;

	if (! $hat_creation){ #hatbot is more careful with his own assets
		if (int(rand(100)) > 95){
			$new_hats = $past_hats + 111;
			$bonus = 'has a sticky keyboard, resulting in 111 hats for '.$_[0].'!';
		}
	}
	if ($hat_creation){
		if ($hats > $hats{'BANK'}{'hats'}){
			$hats = $hats{'BANK'}{'hats'};
			$new_hats = $past_hats + $hats{'BANK'}{'hats'};
		}
		if ($hats{'BANK'}{'hats'} <= 0){
			return 'is ruined.';
		}
	}

	$hats{$them}{'last_time'} = time;
	$hats{$them}{'hats'} = $new_hats;
	$hats{'BANK'}{'hats'} -= $hats;

	tied(%hats)->save;

	my $out;
	if ($bonus){
		$out = $bonus;
	} else {
		$out = 'gives '.$hats.' hats to '.$_[0].' for a total of '.$new_hats.' hats.';
	}
	return ($out, $hats, $new_hats);
}
sub hat_check {
	my $them = lc $_[0];
	my $hat_timeout = Irssi::settings_get_int('hat_timeout');
	return 'has '.$_[0].' at '.$hats{$them}{'hats'}.' hats. '.$_[0].' is due for max hats in '.fuzz($hats{$them}{'last_time'} + $hat_timeout).'.';
}
sub fedoras {
	my ($top, $bottom) = @_;

	$bottom =~ s/^.+?dora\s*//i;
	my @params = split /\s+/, $bottom;

	if ($params[-1] =~ /\D/){ #do a string operation to make sure it is a number
		push @params, 1;
	} else { #doing that regex might have turned it into a string? ┐(°o ° )┌
		$params[-1] += 0;
	}

	if ($debug_mode){
		print $_ for @params;
	}

	if (lc $params[0] eq 'buyout'){
		#maybe this is altruism
		my $recipient = lc $params[1];
		if ($recipient ne 'buyout' && exists $hats{$recipient}{'fedoras'}){
			# if ($debug_mode){
			# 	print "$top is trying to buy out one of $recipient"."'s fedoras.";
			# }
		#but it probably isn't
		} else { 
			$recipient = $top;
		}

		if ($params[-1] > $hats{$recipient}{'fedoras'}){
			$params[-1] = $hats{$recipient}{'fedoras'};
		}

		my $charge = fedora_buyout_price($recipient); #could set it to $top's price if you want to be meaner
		$charge *= $params[-1];

		if ($hats{lc $recipient}{'fedoras'} == 0){
			return "cannot solve your problems.";
		} elsif ($hats{lc $top}{'hats'} < $charge){
			return "knows you don't have $charge hats.";
		}		

		$hats{lc $top}{'hats'} -= $charge;
		$hats{lc $top}{'tx_ttl'} += $charge;
		$hats{lc $recipient}{'fedoras'} -= $params[-1];
		$hats{'BANK'}{'hats'} += $charge;

		tied(%hats)->save;

		my $out = 'misplaces a fedora while accepting '.$top.'\'s gift of '.$charge.' hats. ';
		if ($params[-1] > 1){
			$out =~ s/a fedora/$params[-1] fedoras/;
		}

		if ($hats{lc $recipient}{'fedoras'} > 0){
			$out .= $recipient.' will have to make do with '.$hats{lc $recipient}{'fedoras'}.' fedoras.';
		} else {
			$out .= $recipient.' is out of fedoras. Hatbot apologizes.';
		}
		return $out;
	} else {
		$bottom = lc $params[0];
		if (! exists $hats{lc $bottom}){ #there are many saner ways to validate a nick <_<
			return "does not think $bottom is a person.";
		} elsif (! $bottom || $bottom eq '') {
			return "needs a target.";
		}
		if (! exists $params[1]){
			push @params, 1;
		}
		$params[-1] = 0 + $params[-1]; #just to be sure

		my $price = Irssi::settings_get_int('hat_fedora_price');
		$price *= $params[-1];
		if ($hats{lc $top}{'hats'} < $price){
			return "demands at least $price hats for this service.";
		}
		$hats{lc $top}{'hats'} -= $price;
		$hats{lc $top}{'tx_ttl'} += $price;
		$hats{lc $bottom}{'fedoras'} += $params[-1];

		$hats{'BANK'}{'hats'} += $price;

		tied(%hats)->save;

		my $return = 'takes '.$price.' of '.$top.'\'s hats and places a fedora on '.$bottom.'\'s head';
		if ($params[-1] > 1){
			$return =~ s/places a fedora/stacks $params[-1] fedoras/;
		}

		return $return;
	}
}
sub fedora_buyout_price {
	my $person = $_[0];
	my $price = Irssi::settings_get_int('hat_fedora_price');
	$price += ($price - (score($person))[1]);
	return int($price);
}
sub reset_times {
	for (keys %hats){
		$hats{$_}{'last_time'} = 8;
	}
	tied(%hats)->save;
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

	if (! exists $hats{lc $nick}{'last_bet'}){
		$hats{lc $nick}{'last_bet'} = time - 600;
	} elsif (! exists $hats{lc $nick}{'hats'}){ # it is possible for a noob to randomly try gambling
		$hats{lc $nick}{'hats'} = 0;
	}

	#anti-flood
	my $bet_timeout = Irssi::settings_get_int('hat_bet_timeout');
	if (time - $hats{lc $nick}{'last_bet'} < $bet_timeout){
		if (time - $hats{lc $nick}{'last_trigger'} < 2){
			return 'STOP';
		}
		return "advises you to slow down and consider your actions.";
	}

	$hats{lc $nick}{'last_bet'} = time;
	my $bet = $hats{lc $nick}{'hats'};
	if ($text =~ /\b(\d+)/){ #default bet is everything but you can be a babby if you want
		if ($1 < $bet){
			$bet = $1;
		} elsif ($1 > $bet){ # don't try to bet more than you have
			return "is not stupid. You only have $bet hats.";
		}
		$custom++;
	} elsif ($text =~ /half/i){
		$bet = int($hats{lc $nick}{'hats'} / 2);
		$custom++;
	} elsif ($text =~ /mod(\d\d*)/i){
		if ($1 && $1 != 0){
			$bet = int($hats{lc $nick}{'hats'} % $1);
			$custom++;
		} else {
			return "cannot read this shit.";
		}
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

	# adjust odds
	my $odds = 100;
	my $bot_odds = 100;
	my $mods = 0;
	my $win; 
	if (exists $hats{lc $nick}{'fedoras'}){ #punish them for fedora ownership
		$odds -= $hats{lc $nick}{'fedoras'};
	}
	if ($hats{lc $nick}{'hats'} / $bet > 10){ #punish them for betting safely
		$mods -= 5;
	} elsif ($hats{lc $nick}{'hats'} / $bet <= 2){ #also the reverse
		$mods += 5;
	}
	if ($hats{lc $nick}{'hats'} > $hats{'BANK'}{'hats'}){ #punish them for being rich
		$mods -= 5;
	} else {
		$mods += 5;
	}

	if (exists $hats{'hatbot'}{'fedoras'}){ #I'm hardcoding the bot's nick, shoot me
		$bot_odds -= $hats{'hatbot'}{'fedoras'}; #also I'm using hatbot where everything else uses BANK
	}

	my @res = (rand $odds, $odds, $mods, $bot_odds, rand $bot_odds);
	if ($debug_mode){
		print "$nick bet: ".(join ', ', @res);
	}

	if (($res[0] + $mods) > $res[-1]){
		$win = 1;
	} else {
		$win = 0;
	}

	my $return;
	if ($win){ #they win
		$hats{lc $nick}{'hats'} += $bet;
		$hats{lc $nick}{'tx_ttl'} += $bet;
		$hats{'BANK'}{'hats'} -= $bet;

		tied(%hats)->save;

		$return = 'raises '.$nick.'\'s balance to '.$hats{lc $nick}{'hats'}.' hats. Hatbot retains '.$hats{'BANK'}{'hats'}.' hats.';
	} else { #house wins
		$hats{lc $nick}{'hats'} -= $bet;
		$hats{lc $nick}{'tx_ttl'} += $bet;
		$hats{'BANK'}{'hats'} += $bet;

		tied(%hats)->save;

		$return = 'lowers '.$nick.'\'s balance to '.$hats{lc $nick}{'hats'}.' hats. Hatbot now holds '.$hats{'BANK'}{'hats'}.' hats.';
	}
	return $return;
}
sub lottery {
	my @contestants;
	my $pot = 0;

	$hats{'BANK'}{'lotto_last'} = (gmtime)[2];

	for my $p (keys %hats){
		if (! $hats{$p}{'tx_ttl'}){ #initialize
			$hats{$p}{'tx_ttl'} = 0;
		}

		#this isn't a real lottery or raffle, for any number of reasons
		if ($hats{$p}{'tx_ttl'} > 50){ #they're elegible if they've done 50 hats worth of hat transactions since last lottery
			$pot += $hats{$p}{'tx_ttl'} / 5; #pot is 20% of (most) transactions

			if ($p ne 'BANK'){
				push @contestants, $p;
			}
		}
	}
	$pot = int $pot;

	if ($debug_mode){
		print "Jackpot is $pot hats. ".(scalar @contestants)." eligible players.";
	}

	#TODO: consider making minimum $pot configurable
	if ($pot < 100 || $#contestants < 1){ #I could let the single qualifying contestant win it, but...why
		return 'STOP';
	}

	#now pick a winner
	#TODO: make fedoras drop chances
	#bug(?): all nicks are lowercased because they're just the hash keys
	my $w = $contestants[int rand @contestants];

	#hatbot's gonna sweeten the deal
	my $bonus = 0;
	if ($pot < ($hats{'BANK'}{'hats'} / 24)){ #4% is probably safe, right?
		$bonus = int($hats{'BANK'}{'hats'} / 24);
		$bonus %= (8 * $pot); #I have no rational basis for this number
	}

	if (! $hat_creation){ #oh wait are there even hats
		if ($bonus < $pot){ return 'STOP'; }
		$pot = 0;
	}

	$hats{$w}{'hats'} += $pot;
	$hats{$w}{'hats'} += $bonus;
	$hats{'BANK'}{'hats'} -= $bonus;

	if ($debug_mode){
		print "Winner is $w";
		print "hatbot contributed $bonus hats.";
	}

	for my $p (@contestants){ #wiping only @contestants allows slower people to maybe qualify next time
		$hats{$p}{'tx_ttl'} = 0;
	}
	
	tied(%hats)->save;

	my $there;
	if (! $hats{$w}{'last_chan'}){
		$there = $_[0];
	} else {
		$there = $hats{$w}{'last_chan'};
	}

	return ("writes a giant foam check for ".($pot + $bonus)." hats and gives it to $w", $there);
}
sub fuzz { #why is there no cpan module for fuzzing lengths of time? only absolute times
	my $then = $_[0];
	my $len = $then - time;

	my %hms = (
		hour => 0,
		min => 0,
		sec => 0,
	);

	if ($len >= 3600){
		$hms{'hour'} = int($len / 3600);
	}
	if ($len % 3600 >= 60){
		$hms{'min'} = int(($len % 3600) / 60);
	}
	if ($len % 60){
		$hms{'sec'} = $len % 60;
	}

	if ($hms{'min'} < 15){
		$hms{'fmin'} = 0;
		$hms{'fhour'} = $hms{'hour'};
	} elsif ($hms{'min'} > 45){
		$hms{'fhour'} = $hms{'hour'} + 1;
		$hms{'fmin'} = 0;
	} else {
		$hms{'fmin'} = 30;
		$hms{'fhour'} = $hms{'hour'};
	}

	my $out = $hms{'fhour'}.'h'.$hms{'fmin'}.'m';

	#don't laugh unless you can show me something better
	$out =~ s/0h0m/time/;
	$out =~ s/0h//;
	$out =~ s/1h/an hour/;
	$out =~ s/2h/two hours/;
	$out =~ s/3h/three hours/;

	$out =~ s/(?<!\d)0m//;
	$out =~ s/^30m/half an hour/;
	$out =~ s/hour30m/hour and a half/;
	$out =~ s/hours30m/and a half hours/;
	return $out;
}
sub drain_fedoras {
	my ($tgt, $quant, $price) = @_;

	if (! exists $hats{$tgt}{'fedoras'}){
		return 0;
	}

	my $o = $hats{$tgt}{'fedoras'};
	$o *= $price;

	$hats{$tgt}{'fedoras'} = 0;
	#don't save to disk in here or it'll take years
	return $o;
}
sub go_bankrupt {
	if ($already_poor){
		return 'STOP';
	}
	my $payout = 0;
	for my $v (keys %hats){
		$payout += drain_fedoras($v, 'max', Irssi::settings_get_int('hat_fedora_price'));
	}

	if ($payout == 0){
		$already_poor++;
		return 'STOP';
	}
	$already_poor = 0;

	$hats{'BANK'}{'hats'} += $payout;
	tied(%hats)->save;

	return 'sells all the fedoras and reincorporates under a different name.';
}

Irssi::signal_add("event privmsg", "event_privmsg");
Irssi::command_bind("hat_party", \&reset_times);