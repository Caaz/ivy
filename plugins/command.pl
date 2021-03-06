%plugin = (
required => 1,
prereq => { plugins => ['user'] },
hook => {
	begin => sub {
		my $data = shift;
		if(!$$data{prefix}) { $u{utility}{ask}('What prefix do you want to use for commands on your bot? This works as a regex prefix.',"(~|-)",\$$data{prefix}); }
		save();
	},
	irc => sub {
		my ($data,$tmp,$handle,$msg) = splice @_,0,4;
		if($msg =~ /^\:(?<nick>.+?)\!(?<user>.+?)\@(?<host>.+?) (?<type>\w+?) (?<where>.+?) \:(?<rawmsg>.+)$/) {
			my $network = $u{network}{keyByHandle}($handle);
			my %parsed = %+;
			my $prefix = "(?:".$$data{prefix}.")";
			if($parsed{where} !~ /^\x23/) { $prefix .= '?'; $parsed{where} = $parsed{nick}; }
			$parsed{msg} = $parsed{rawmsg};
			$u{utility}{stripCodes}(\$parsed{msg});
			for my $key (keys %{ $ivy{plugin} }) {
				my $plugin = $ivy{plugin}{$key};
				for my $regex (keys %{ $$plugin{commands} }) {
					if($parsed{msg} =~ /^$prefix$regex\s*$/i) {
						next if(($$tmp{$parsed{user}}{$regex}) && (time < $$tmp{$parsed{user}}{$regex}));
						
						my $userID = $u{user}{get}($parsed{nick},$parsed{user},$network);
						my $access = ($$plugin{commands}{$regex}{access})?$$plugin{commands}{$regex}{access}:0;
						if(($access) && (($userID == -1) || ($ivy{data}{user}{db}[ $userID ]{access} < $access))) {
							$u{prism}{msg}($handle,$parsed{where},'command.access_required',{required=>$access,yours=>($userID!=-1)?$ivy{data}{user}{db}[ $userID ]{access}:0});
							next;
						}
						
						$$plugin{commands}{$regex}{code}(
						
							$handle,
							\%parsed,
							$ivy{data}{$key},
							$ivy{tmp}{$key},
							$network,
							$userID
							
						) if $$plugin{commands}{$regex}{code};
						$$tmp{$parsed{user}}{$regex} = time+$$plugin{commands}{$regex}{cooldown} if $$plugin{commands}{$regex}{cooldown};
						last;
					}
				}
			}
		}
	}
},
strings => {
	fun => {
		json => {
			access_required => "{success:\x04false\x04,error:\"Not enough access.\",required:{required},yours:{yours}}"
		}
	},
	en => {
		us => {
			access_required => 'You don\'t have enough access to use this command. [Required {required}] [You {yours}]'
		}
	}
}
);