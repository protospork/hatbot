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

$VERSION = "0.2.6";
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

	if ($text =~ /^\s*\.hats?$/i){
		$return = (give_hats($nick))[0];
	} elsif ($text =~ /^\s*\.fedora (\w+)/i){
		# $return = fedoras($nick, $1);
		return;
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

	if ($bottom){
		return "does not think $bottom is a person.";
	} elsif (! $bottom) {
		return "needs a target.";
	}
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