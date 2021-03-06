#!/usr/bin/perl
use warnings;
use strict;
use Cwd 'abs_path';
use IO::Select;
use IO::Socket;
use JSON;
no warnings "experimental"; # You can't tell me how to live my life.
my %ivy = (
	'debug'=>1,
	'select'=>IO::Select->new()
); 
my %u;
eval("use Android"); if($@){ $ivy{os} = $^O; } else { $ivy{os} = "android"; eval('$ivy{droid} = Android->new();'); }
goLocal();
load();
loadPlugins();
plugins(['load','begin','connect']);
while(1) {
	plugins(['tick']) if((!$ivy{tick}) || (time != $ivy{tick}));
	$ivy{tick} = time;
	for my $fh ($ivy{select}->can_read(1)) {
		my $rawmsg = readline($fh);
		if(!$rawmsg) {
			plugins(['disconnected'],[ $fh ]);
			$ivy{select}->remove($fh);
			$fh->close;
			next;
		}
		$rawmsg =~ s/\n|\r//g; 
		plugins(['irc'],[$fh,$rawmsg]);
	}
	sleep 1 unless($ivy{select}->count);
}
sub loadPlugins {
	my $d = ($ivy{debug}); my @errors;
	for my $dir ('plugins','plugins.local') {
		mkdir($dir) if(!-e $dir);
		print "Checking $dir\n" if $d;
		for my $file (<$dir/*.pl>) {
			my ($key,$time) = ($file, (stat($file))[9]);
			$key =~ s/.*[\\\/](.+).pl/$1/i;
			if((!$ivy{lastUpdated}{$key}) || ($ivy{lastUpdated}{$key} != $time)) {
				$ivy{lastUpdated}{$key} = $time;
				print "- Loading $file\n" if $d; 
				my %plugin = ();
				open PLUGIN, "<$file"; eval(join "", <PLUGIN>); close PLUGIN;
				if($@) { 
					warn $@;
					push(@errors,{message=>$@,plugin=>$key}); 
				}
				else { 
					print "- $key loaded.\n" if $d; 
					$ivy{plugin}{$key} = \%plugin; 
				}
			}
		}
	}
	my $modified = 1;
	while($modified) {
		$modified = 0;
		for my $plug (keys %{$ivy{plugin}}) {
			for my $req (@{ $ivy{plugin}{$plug}{prereq}{modules} }) { eval("use $req;"); if($@) { $modified = $req; } }
			for my $req (@{ $ivy{plugin}{$plug}{prereq}{plugins} }) { if(!$ivy{plugin}{$req}){ $modified = $req; } }
			if($modified) {
				push(@errors, {plugin=>$plug,message=>"Didn't meet dependency ($modified)"});
				warn "Deleting plugin $plug. Didn't meet dependency ($modified)";
				die "Can't continue without this plugin." if($ivy{plugin}{$plug}{required});
				delete $ivy{plugin}{$plug};
			}
		}
	}
	plugins(['init']);
	return \@errors;
}
sub plugins {
	my ($actions,$args) = (shift,shift); my @errors;
	for my $action (@{ $actions }) {
		for my $key (keys %{ $ivy{plugin} }) { 
			for my $type ('data','tmp') { %{$ivy{$type}{$key}} = () if(!$ivy{$type}{$key}); }
			eval { $ivy{plugin}{$key}{hook}{$action}($ivy{data}{$key},$ivy{tmp}{$key},@{$args}) if $ivy{plugin}{$key}{hook}{$action}; }; 
			if($@) { push(@errors,{error=>$@,plugin=>$key}); warn $@; }
		}
	}
	return \@errors;
}
sub load {
	mkdir('data') if(!-e 'data');
	for my $file (<data/*.json>) {
		my $key = $file; $key =~ s/.*[\\\/](.+).json/$1/; 
		eval { open DATA, "<$file"; %{ $ivy{data}{$key} } = %{ decode_json(join "", <DATA>) }; close DATA; } or warn $@;
	}
	plugins(['load']);
}
sub save { 
	mkdir('data') if(!-e 'data');
	for my $plugin (keys %{ $ivy{data} }) {
		if(keys %{ $ivy{data}{$plugin} }) {
			eval { open DATA, ">data/$plugin.json"; print DATA encode_json($ivy{data}{$plugin}); close DATA; } or warn $@; 
		}
	}
	plugins(['save']);
}
sub goLocal { my $directory; ($directory = abs_path($0)) =~ s/([\\\/])[^\\\/]+?\.pl$/$1/; chdir($directory) or die "Couldn't chdir to $directory. $!"; }
sub raw { my $handle = shift; for(@_) { print $handle "$_\n"; print "$_\n"; } }