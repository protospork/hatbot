use Modern::Perl;
use Tie::YAML;

tie my %hats, 'Tie::YAML', $ENV{HOME}.'/.irssi/scripts/cfg/hats.po' or die $!;

for (keys %hats){
	$hats{$_}{'last_time'} = 8;

	tied(%hats)->save;
}