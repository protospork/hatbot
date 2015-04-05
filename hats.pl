#TODO:
#port database to SQL
#find a nick that doesn't blow

use vars qw($VERSION %IRSSI);
use Modern::Perl;
use Tie::YAML;

$VERSION = "1.0.0";
%IRSSI = (
    authors => 'protospork',
    contact => 'https://github.com/protospork',
    name => 'hats',
    description => 'a dumb game/societal worth calculator',
    license => 'MIT/X11'
);
Irssi::settings_add_str('hatbot', 'hat_channels', '#wat');



tie my %hats, 'Tie::YAML', $ENV{HOME}.'/.irssi/scripts/cfg/hats.po' or die $!;

sub event_privmsg {
	my ($server, $data, $nick, $mask) = @_;
	my ($target, $text) = split(/ :/, $data, 2);
	my $return;

	my @enabled_chans = split /,/, Irssi::settings_get_str('hat_channels');
	return unless grep lc $target eq lc $_, (@enabled_chans);

	if ($text =~ /^\s*\.hats?\b/i){
		$return = (give_hats($nick))[0];
	} elsif ($text =~ /^\s*\.fedora (\w+)/i){
		$return = fedoras($nick, $1);
	} elsif ($text =~ /^\s*\.enl(?:ighten(?:ment)?)? (\w+)/i){
		$return = (score($1))[0];
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


	if (exists $hats{$them}{'last_time'}){
		if (time - $hats{$them}{'last_time'} < 86400){
			my $no = pluralize('thinks '.$_[0].' should be content with '.$hats{$them}{'hats'}.' hat');
			return $no;
		}
	} else {
		$hats{$them}{'last_time'} = 0;
	}

	$hats{$them}{'last_time'} = time;
	
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

	$num > 1 # why does this work...
		? $string .= 's'
		: $string .= '.';

	return $string;
}

Irssi::signal_add("event privmsg", "event_privmsg");
Irssi::command_bind("hat_party", \&reset_times);