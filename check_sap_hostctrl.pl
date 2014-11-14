#!/usr/bin/perl

## Copyright (c) 20014 Kai Knoepfel
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either version 2
## of the License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

use Getopt::Long;

my %conf = (
	timedef		=> "30",									# timeout of plugin
	sudo 		=> "/usr/bin/sudo su - root -c",			# path to sudo command
	sapcontrol 	=> "/usr/sap/hostctrl/exe/sapcontrol",		# path to sapcontrol binarie
	ps			=> "/bin/ps -ef",							# path to ps command
	usrbin		=> "/usr/bin",								# path to /usr/bin
	diatime		=> "5",										# timevalue for dialogprocesses, only the dialogprocesses with a runtime over 5 sec. are interrested
	btctime		=> "1800",									# timevalue for batchprocesses, only the batchprocesses with a runtime over 30 sec. are interrested
	updtime		=> "30",									# timevalue for upd- and up2 processes, only the upd- and up2-processes with a runtime over 5 sec. are interrested
	spotime		=> "60",
	);


#
# Dont change anything below these lines ...
#


GetOptions(
    "v"         => \$ver,
    "version"   => \$ver,
    "h"         => \$help,
    "help"      => \$help,			
    "sysnr=i"	=> \$sysnr,			# sapsystem number
    "meth=s"    => \$meth,			# monitoring methode
    "obj=s"     => \$obj,			# monitoring object
    "backend=s" => \$backend,		# type of backend-system
    "warn=o"    => \$warn,			# warning level
    "crit=o" 	=> \$crit,			# critical level
    "t=i"       => \$timec,			# timeout of the check
    "time=i" 	=> \$timec,			# timeout of the check
    "sudo=i"	=> \$sudo,			# use or don´t use sudo
    "host=s"	=> \$host,			# monitored-system
    "user=s"	=> \$user,			# monitoring user on remote-system
    "function=s"	=> \$func,			# define the sapcontrol function other then ccms / now: alpha feature
	);


version();
help();
timeout();
        

# timeout routine
$SIG{ALRM} = \&plugin_timeout;
eval {
		alarm ($timeout);
        };
     


# sap routine
if ( $meth eq "sap" )
	{
	sapctrl();
	if ( $rc_command == "0" )
		{
			saproutine_out();
		}
	elsif ( $rc_command > "0" )
		{
			unknown_obj();
		}
	}
	
# nagios routine	
elsif ( $meth eq "nag" )
	{
		if ( $warn ne undef && $crit ne undef )
			{
				sapctrl();		
			}
		else
			{
				print "UNKNOWN - you must define a warning-level and a critical level with monitoring-methode nag.\n";
				exit 3;
			}
		
	if ( $rc_command == 0 )
		{	
			nagroutine_out();
		}
	
	elsif ( $rc_command > 0)
		{
			unknown_obj();
		}
	}

# list objects routine
elsif ( $meth eq "ls" )
	{
		sapctrl_ls();
	}
	
# sapcontrol without ccms function
elsif ( $meth eq "cons")
	{
		sapctrl_cons();
	}
	
	
	
sub precheck{
	if ( $sudo == "1" )
		{
			# sapstartsrv must running to use the binary sapsontrol. sapstartsrv starts with systemstart.
			# print "precheck\n";
			@startsrv_run = `ssh $host -l $user '$conf{ps} | grep sapstartsrv | grep $sysnr | grep -v "^$user"'`;
			$startsrv_num = @startsrv_run;
				
			if ( $startsrv_num == "0" )
				{
					print "UNKNWON - sapstartsrv not working on host: $host\n";
					print "You can use sapcontrol to start sapstartsrv!!\n";
					print "./sapcontrol -nr $sysnr -function StartService <SID>\n";
					exit 3;
				}		
		}
	else
		{
			my $command = `$conf{sapcontrol} -host $host -nr $sysnr -function GetSystemInstanceList`;
			my $rc_command = $?;
			if ( $rc_command > "0" )
				{
					print "UNKNWON - sapstart not working on host: $host or the systemnumber is wrong.\n";
					print "You can use the following command on the remote-system:\n";
					print "./sapcontrol -nr $sysnr -function StartService <SID>\n";
					print "$command\n";
					exit 3;		
				}
			
		}
	
	}

sub sapctrl{
	if ( $sudo == "1")
		{
			#use sapcontrol on remoteinstance with sudo command
			my $command = `ssh $host -l $user "$conf{sudo} '$conf{sapcontrol} -nr $sysnr -function GetAlertTree' | $conf{usrbin}/grep -F '$obj'"`;
			$rc_command = $?;
			#print "$command\n";
			if ( $rc_command > "0" )
				{
					precheck();
				}
			#print "rc->$rc_command\n";
			chomp $command;
			chomp $rc_command;
			@command_split = split /,/, $command;
			$command_split[2] =~ s/ //;			# sap returncode (green, yellow, red, gray)
			$command_split[3] =~ s/ //;			# sap performance value
			@perf = split / /, $command_split[3];
			
			$monitoring_object = $command_split[0];		# monitoring-objekt 						-> only doku, nothing todo with this variable
			$sap_returncode = $command_split[2];		# sap returncode (green, yellow, red, gray) -> only doku, nothing todo with this variable
			$perf_value = $perf[0];						# performance value 						
			$perf_unit = $perf[1];						# performance unit
			chomp $monitoring_object;
			chomp $sap_returncode;
			chomp $perf[1];
			chomp $perf[2];
			#print "obj:$monitoring_object, rc:$sap_returncode, perf_val:$perf_value"."$perf_unit\n";
		}
	else
		{
			#use sapcontrol on icinga-host
			my $command = `$conf{sapcontrol} -host $host -nr $sysnr -function GetAlertTree | $conf{usrbin}/grep -w '$obj'`;
			$rc_command = $?;
			if ( $rc_command > "0" )
				{
					precheck();
				}
			#print "output->$command\n";
			#rint "rc->$rc_command\n";
			chomp $command;
			chomp $rc_command;
			@command_split = split /,/, $command;
			$command_split[2] =~ s/ //;			# sap returncode (green, yellow, red, gray)
			$command_split[3] =~ s/ //;			# sap performance value
			@perf = split / /, $command_split[3];
			
			$monitoring_object = $command_split[0];		# monitoring-objekt 						-> only doku, nothing todo with this variable
			$sap_returncode = $command_split[2];		# sap returncode (green, yellow, red, gray) -> only doku, nothing todo with this variable
			$perf_value = $perf[0];						# performance value 						
			$perf_unit = $perf[1];						# performance unit
			chomp $monitoring_object;
			chomp $sap_returncode;
			chomp $perf[1];
			chomp $perf[2];
			#print "obj:$monitoring_object, rc:$sap_returncode, perf_val:$perf_value"."$perf_unit\n";
		}
	
	
	if ( $obj ne "Shortdumps" )
		{
			$command_split[3] =~ s/ //g;		# sap result		
		}
	
	if ( $backend eq "java")
		{
			$sum_node = (@command_split-1)/10;		# anzahl servernodes
			$a = 10;
			$c = 3;
			for ( $i=0; $i<$sum_node; $i++)
				{
					@adv = split /;/, $command_split[$a];
					@adv1 = split / /, $adv[1];
					$node = $adv1[3];	
					$command_split[$c] =~ s/ //g;
					push @other, "\'NodeID:$node\'=$command_split[$c]";
					push @alarmlevel, "$command_split[$c]";
					$a += 10;
					$c += 10;
				}
			
			@sort_a = reverse sort(@alarmlevel);
			$greatest = $sort_a[0];
			
			}
 	}
	
sub sapctrl_cons{
	if ( $sudo == "1")
		{
			#use sapcontrol on remoteinstance with sudo command
			my $command = `ssh $host -l $user "$conf{sudo} '$conf{sapcontrol} -nr $sysnr -function $func'"`;
			my $com_grep = grep /FAIL/, $command;
			#print "$command\n";
			#print "$com_grep\n";
			if ( $com_grep != 0 )
				{
					print "UNKNOWN - $command\n";
					exit 3;
				}
			if ( $func eq "ABAPGetWPTable" )
				{
					abapgetwptable();
					nagroutine_out();
					
				}
		}
	else
		{
			# use sapcontrol client from nagios-server
			$command = `$conf{sapcontrol} -host $host -nr $sysnr -function $func`;
			my $com_grep = grep /FAIL/, $command;
			#print "$command\n";
			#print "$com_grep\n";
			if ( $com_grep != 0 )
				{
					print "UNKNOWN - $command\n";
					exit 3;
				}
			if ( $func eq "ABAPGetWPTable" )
				{
					abapgetwptable();
					nagroutine_out();
					
				}			
		}
}

sub abapgetwptable{
	@wptable = split /\n/, $command;
	# number of all sap processes
	my $sum_wp = @wptable;
	#print "$sum_wp\n";
	
	
	
	# number of dialog proc
	@dia = grep /DIA/, @wptable;
	my $sum_dia = @dia;
	@dia_run = grep /Run|Ended|Stop/, @dia;
	my $sum_diarun = @dia_run;
	#print "sum_dia_orig_run:$sum_diarun\n";
	
	# number of upd proc
	@upd = grep /UPD/, @wptable;
	my $sum_upd = @upd;
	@upd_run = grep /Run|Ended|Stop/, @upd;
	my $sum_updrun = @upd_run;
	
	# number of enq proc
	@enq = grep /ENQ/, @wptable;
	my $sum_enq = @enq;
	#print "ENQ: $sum_enq\n";
						
	# number of BTC proc
	@btc = grep /BTC/, @wptable;
	my $sum_btc = @btc;
	@btc_run = grep /Run|Ended|Stop/, @btc;
	my $sum_btcrun = @btc_run;
	
	# number of spool proc
	@spo = grep /SPO/, @wptable;
	my $sum_spo = @spo;
	@spo_run = grep /Run|Ended|Stop/, @spo;
	my $sum_sporun = @spo_run;
					
	# number of up2 proc
	@up2 = grep /UP2/, @wptable;
	my $sum_up2 = @up2;
	

	
	for ( $i=0; $i<$sum_diarun; $i++)
		{
			@dia_split_time = split /\,/, $dia_run[$i];
			if ( $dia_split_time[9] > $conf{diatime} )
				{
					if ( $sum_diarun_otime == 0 )
						{
							my $sum_diarun_otime = 1;		
						}
					$sum_diarun_otime = $sum_diarun_otime + 1;
				}
			elsif ( $sum_diarun_otime == 0 )
				{
					$sum_diarun_otime = "0";
				}	
		}
	
		
	for ( $i=0; $i<$sum_updrun; $i++)
		{
			@upd_split_time = split /\,/, $upd_run[$i];
			if ( $upd_split_time[9] > $conf{updtime} )
				{
					if ( $sum_updrun_otime == 0 )
						{
							my $sum_updrun_otime = 1;		
						}
					$sum_updrun_otime = $sum_updrun_otime + 1;
				}	
			elsif ( $sum_updrun_otime == 0 )
				{
					$sum_updrun_otime = "0";
				}
		}
	
	for ( $i=0; $i<$sum_btcrun; $i++)
		{
			@btc_split_time = split /\,/, $btc_run[$i];
			if ( $btc_split_time[9] > $conf{btctime} )
				{
					if ( $sum_btcrun_otime == 0 )
						{
							my $sum_btcrun_otime = 1;		
						}
					$sum_btcrun_otime = $sum_btcrun_otime + 1;
				}
			elsif ( $sum_btcrun_otime == 0 )
				{
					$sum_btcrun_otime = "0";
				}
							
		}
	for ( $i=0; $i<$sum_sporun; $i++)
		{
			@spo_split_time = split /\,/, $spo_run[$i];
			if ( $spo_split_time[9] > $conf{spotime} )
				{
					if ( $sum_sporun_otime == 0 )
						{
							my $sum_sporun_otime = 1;		
						}
					$sum_sporun_otime = $sum_sporun_otime + 1;
				}
			elsif ( $sum_sporun_otime == 0 )
				{
					$sum_sporun_otime = "0";
				}		
		}	
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		

# calculating measured data
		
	if ( $sum_diarun == "0" )
		{
			$sum_diarun_otime = "0";
		}

	if ( $sum_diarun_otime == 0 )
		{
			$perc_used_dia = "0";
		}
	else
		{
			$perc_used_dia = int($sum_diarun_otime*100/$sum_dia);	
		}		
	$dia_use = "DIA $sum_diarun_otime/$sum_dia $perc_used_dia";
	@dia_sort = split / /, $dia_use;
	#print "$dia_use\n";
	
	
			
	
	
	if ( $sum_updrun == "0" )
		{
			$sum_updrun_otime = "0";
		}
	if ( $sum_updrun_otime == 0 )
		{
			$perc_used_upd = "0";
		}
	else
		{
			$perc_used_upd = int($sum_updrun_otime*100/$sum_upd);
		};
	$upd_use = "UPD $sum_updrun_otime/$sum_upd $perc_used_upd";
	@upd_sort = split / /, $upd_use;
	#print "$upd_use\n";
	
	
					
	

	
	if ( $sum_btcrun == "0" )
		{
			$sum_btcrun_otime = "0";
		}
	if ( $sum_btcrun_otime == "0")
		{
			$perc_used_btc = "0";
		}
	else
		{
			$perc_used_btc = int($sum_btcrun_otime*100/$sum_btc);		
		};
	$btc_use = "BTC $sum_btcrun_otime/$sum_btc $perc_used_btc";
	@btc_sort = split / /, $btc_use;
	#print "$btc_use\n";
				
		
				
	
	if ( $sum_sporun == "0" )
		{
			$sum_sporun_otime = "0";
		}
	if ( $sum_sporun_otime == "0" )
		{
			$perc_used_spo = "0";
		}
	else
		{
			$perc_used_spo = int($sum_sporun_otime*100/$sum_spo);		
		};
	$spo_use = "SPO $sum_sporun_otime/$sum_spo $perc_used_spo";
	@spo_sort = split / /, $spo_use;
	#print "$spo_use\n";
		
		
		

	if ( $sum_up2 > 0 )
		{
			@up2_run = grep /Run/, @up2;
			my $sum_up2run = @up2_run;
			for ( $i=0; $i<$sum_up2run; $i++)
				{
					@up2_split_time = split /\,/, $up2_run[$i];
					#print "time$i:$up2_split_time[9]\n";
					if ( $up2_split_time[9] > $conf{updtime} )
						{
							if ( $sum_up2run_otime == 0 )
								{
									my $sum_up2run_otime = 1;		
								}
							$sum_up2run_otime = $sum_up2run_otime + 1;
						}	
					elsif ( $sum_up2run_otime == 0 )
						{
							$sum_up2run_otime = "0";
						}	
				
				}
				
				
			if ( $sum_up2run == "0" )
				{
					$sum_up2run_otime = "0";
				}
			if ( $sum_up2run_otime == "0")
				{
					$perc_used_up2 = "0";
				}
			else
				{
					$perc_used_up2 = int($sum_up2run_otime*100/$sum_up2);		
				};
			$up2_use = "UP2 $sum_up2run_otime/$sum_up2 $perc_used_up2";
			@up2_sort = split / /, $up2_use;
			#print "$up2_use\n";
		}
	else
		{
			# up2 processes not configured, set the variable manually to zero
			$perc_used_up2 = "0";
			$up2_use = "UP2 0/0 $perc_used_up";
			@up2_sort = split / /, $up2_use;
			
		}
		
	
	
	# sort highest alarmlevel, this generate the alarmevent critial, warning or ok 
	@alarmlevel = ("$perc_used_btc", "$perc_used_dia", "$perc_used_spo", "$perc_used_up2", "$perc_used_upd");
	@sort_alarm = reverse sort { $a <=> $b } @alarmlevel;
	#print "@alarmlevel\n";
	#print "@sort_alarm\n";
	$value = $sort_alarm[0];
 	$perf_unit = "%";
	
	
		
	@grep_dia = grep /$value/, @dia_sort;
	@grep_btc = grep /$value/, @btc_sort;
	@grep_upd = grep /$value/, @upd_sort;
	@grep_up2 = grep /$value/, @up2_sort;
	@grep_spo = grep /$value/, @spo_sort;
	
	
	if ( @grep_dia != "0" )
		{
			$multi_obj = "$dia_use$perf_unit\n $btc_use$perf_unit\n $upd_use$perf_unit\n $spo_use$perf_unit\n $up2_use$perf_unit";
			$multi_perf = "'$dia_sort[0]'="."$dia_sort[2]"."$perf_unit".";"."$warn".";"."$crit".
			","."'$btc_sort[0]'="."$btc_sort[2]"."$perf_unit".
			","."'$upd_sort[0]'="."$upd_sort[2]"."$perf_unit".
			","."'$spo_sort[0]'="."$spo_sort[2]"."$perf_unit".
			","."'$up2_sort[0]'="."$up2_sort[2]"."$perf_unit";
			#print "$multi_obj|$multi_perf\n";
		}
	elsif ( @grep_btc != "0")
		{
			$multi_obj = "$btc_use$perf_unit\n $dia_use$perf_unit\n $upd_use$perf_unit\n $spo_use$perf_unit\n $up2_use$perf_unit";
			$multi_perf = "'$btc_sort[0]'="."$btc_sort[2]"."$perf_unit".";"."$warn".";"."$crit".
			","."'$dia_sort[0]'="."$dia_sort[2]"."$perf_unit".
			","."'$upd_sort[0]'="."$upd_sort[2]"."$perf_unit".
			","."'$spo_sort[0]'="."$spo_sort[2]"."$perf_unit".
			","."'$up2_sort[0]'="."$up2_sort[2]"."$perf_unit";
			#print "$multi_obj|$multi_perf\n";
		}
	elsif ( @grep_upd != "0")
		{
			$multi_obj = "$upd_use$perf_unit\n $dia_use$perf_unit\n $btc_use$perf_unit\n $spo_use$perf_unit\n $up2_use$perf_unit";
			$multi_perf = "'$upd_sort[0]'="."$upd_sort[2]"."$perf_unit".";"."$warn".";"."$crit".
			","."'$dia_sort[0]'="."$dia_sort[2]"."$perf_unit".
			","."'$btc_sort[0]'="."$btc_sort[2]"."$perf_unit".
			","."'$spo_sort[0]'="."$spo_sort[2]"."$perf_unit".
			","."'$up2_sort[0]'="."$up2_sort[2]"."$perf_unit";
			#print "$multi_obj|$multi_perf\n";
		}
	elsif ( @grep_spo != "0")
		{
			$multi_obj = "$spo_use$perf_unit\n $dia_use$perf_unit\n $btc_use$perf_unit\n $upd_use$perf_unit\n $up2_use$perf_unit";
			$multi_perf = "'$spo_sort[0]'="."$spo_sort[2]"."$perf_unit".";"."$warn".";"."$crit".
			","."'$dia_sort[0]'="."$dia_sort[2]"."$perf_unit".
			","."'$btc_sort[0]'="."$btc_sort[2]"."$perf_unit".
			","."'$upd_sort[0]'="."$spo_sort[2]"."$perf_unit".
			","."'$up2_sort[0]'="."$up2_sort[2]"."$perf_unit";
			#print "$multi_obj|$multi_perf\n";
		}
	elsif ( @grep_up2 != "0")
		{
			$multi_obj = "$up2_use$perf_unit\n $dia_use$perf_unit\n $btc_use$perf_unit\n $upd_use$perf_unit\n $spo_use$perf_unit";
			$multi_perf = "'$up2_sort[0]'="."$up2_sort[2]"."$perf_unit".";"."$warn".";"."$crit".
			","."'$dia_sort[0]'="."$dia_sort[2]"."$perf_unit".
			","."'$btc_sort[0]'="."$btc_sort[2]"."$perf_unit".
			","."'$upd_sort[0]'="."$spo_sort[2]"."$perf_unit".
			","."'$spo_sort[0]'="."$up2_sort[2]"."$perf_unit";
			#print "$multi_obj|$multi_perf\n";
		}
	
	
	
					
	my $a = 5;
	for ( $i=0; $i<$sum_wp-5; $i++)
			{
				# for debug proc-table
				#print "$wptable[$a]\n";
				$a += 1;		
			}		
	
	
	#print "DIALOG-PROC: @dia\n";
	#print "DIALIG-PROC-RUNNING:@dia_run\n";
		
			# detail output of running proc´s, now disabled
			# idea: use this for detail-analyse of running procs 
			#$d = 0;
			#for ( $i=0; $i<$sum_diarun; $i++)
			#	{
			#		@run_proc = split /,/, $dia_run[$d];
			#		print "PROC-ID:$run_proc[2] TIME:$run_proc[9] PROGRAM:$run_proc[10] USER:$run_proc[12] ACT:$run_proc[13] TABLE:$run_proc[14]\n";				
			#		$d += 1;
			#	}	
	
	
	
	
}

sub sapctrl_ls{
	if ( $meth eq "ls" )
			{
				if ( $sudo == "1")
					{
						#use sapcontrol on remoteinstance with sudo command
						my $command = `ssh $host -l $user "$conf{sudo} '$conf{sapcontrol} -nr $sysnr -function GetAlertTree -format script'"`;
						my $com_grep = grep /FAIL/, $command;
						#print "$command\n";
						#print "$com_grep\n";
						if ( $com_grep != 0 )
							{
								print "UNKNOWN - $command\n";
								exit 3;
							}
						@command_split = split /;$/m, $command; #Split nach ID´s getrennt
						#print "@command_split\n";
						$stanza = @command_split;
						#print "count: $stanza\n";						
					}
				else
					{
						#use sapcontrol on icinga-host
						my $command = `$conf{sapcontrol} -host $host -nr $sysnr -function GetAlertTree`;
						my $com_grep = grep /FAIL/, $command;
						#print "$command\n";
						#print "$com_grep\n";
						if ( $com_grep != 0 )
							{
								print "UNKNOWN - $command\n";
								exit 3;
							}
						@command_split = split /;$/m, $command; #Split nach ID´s getrennt
						#print "@command_split\n";
						$stanza = @command_split;
						#print "count: $stanza\n";
						#print "was kommt hier: $command_split[1]\n";
					}
				
				
				$b = 10;
				for ( $i=0; $i<$stanza-2; $i++)
					{		
					
						 my @outsplit = split /,/, $command_split[$b];
                         my @advsplit = split /;/, $outsplit[5];
	                     print "Pos.0->Monitoring object, Pos.2->SAP Alarmlevel, Pos.3->Value; Pos.72->Advanced-Value\n";
                         $outsplit[0] =~ s/\n//;
                         print "Pos.0->$outsplit[0]\nPos.2->$outsplit[2]\nPos.3->$outsplit[3]\nPos.72->$advsplit[71]\n";
                         #print "ADV->@advsplit\n";
                         #print "ADV1->$advsplit[71]\n";
                         #$lenght = @advsplit;
                         #print "laenge -> $lenght\n";
                         #print "sap-output:\n";
                         #print "$command_split[$b]\n";
                         print "\n";
                        
						 $b += 1;
					}
				
			}
	}

sub saproutine_out{
	if ( $command_split[2] eq "GREEN" && ($backend eq "abap" || $backend eq "trex") )
		{
  			print "OK - $obj $command_split[3]|$obj=$command_split[3]\n";
  			exit 0;
     	}
	elsif ( $command_split[2] eq "GRAY" && ($backend eq "abap" || $backend eq "trex") )
		{
        	print "UNKNOWN - $obj $command_split[3]|$obj=$command_split[3]\n";
        	print "object not assigned or no return-code delivered\n";
        	exit 3;
        }
	elsif ( $command_split[2] eq "YELLOW" && ($backend eq "abap" || $backend eq "trex"))
		{
        	print "WARNING - $obj $command_split[3]|$obj=$command_split[3]\n";
        	exit 1;
        }
	elsif ( $command_split[2] eq "RED" && ($backend eq "abap" || $backend eq "trex") )
		{
        	print "CRITICAL - $obj $command_split[3]|$obj=$command_split[3]\n";
        	exit 2;
        }
    elsif ( $command_split[2] eq "GREEN" && $backend eq "java" )
		{
			print "OK - @other|@other\n";
        	exit 0;	
		}
	elsif ( $command_split[2] eq "GRAY" && $backend eq "java" )
		{
			print "UNKNOWN - @other\n";
        	exit 3;	
		}
	elsif ( $command_split[2] eq "YELLOW" && $backend eq "java" )
		{
			print "CRITICAL - @other|@other\n";
        	exit 1;	
		}
	elsif ( $command_split[2] eq "RED" && $backend eq "java" )
		{
			print "CRITICAL - @other|@other\n";
        	exit 2;	
		}
	}	

sub timeout{
	if ( $timec != $conf{timedef} )
		{
			$timeout = $timec;
		}
	else
		{ 
			$timeout = $conf{timedef};
		}
	}
	
sub unknown_obj{
	print "UNKNOWN - This monitoring objects is not available!\n";
	print "\n";
	print "Please check the monitoring tree with: check_sap_hostctrl.pl -nr <SYSNR> -meth ls\n";
	exit 3;
	}
	
sub nagroutine_out{
	
	if ( $warn < $crit )
		{
			# print "2\n"; 					# for debugging only
			if ( $perf_value < $warn && ($backend eq "abap" || $backend eq "trex") )
				{
					print "OK - $obj $perf_value"."$perf_unit|$obj=$perf_value"."$perf_unit\n";
        			exit 0;
       			}
			elsif ( ( $perf_value >= $warn && $perf_value < $crit ) && ($backend eq "abap" || $backend eq "trex"))
				{
					print "WARNING - $obj $perf_value"."$perf_unit|$obj=$perf_value"."$perf_unit\n";
       				exit 1;
       			}
			elsif ( $perf_value >= $crit && ($backend eq "abap" || $backend eq "trex") )
				{
					print "CRITICAL - $obj $perf_value"."$perf_unit|$obj=$perf_value"."$perf_unit\n";
        			exit 2;
				}
			elsif ( $greatest < $warn && $backend eq "java" )
				{
					print "OK - @other|@other\n";
        			exit 0;
       			}
    		elsif ( ( $greatest >= $warn && $greatest < $crit ) && $backend eq "java")
				{
					print "WARNING - @other|@other\n";
       				exit 1;
       			}
			elsif ( $greatest >= $crit && $backend eq "java" )
				{
					print "CRITICAL - @other|@other\n";
        			exit 2;
				}
			elsif ( $value < $warn && $backend eq "multi" )
				{
					print "OK - $multi_obj|$multi_perf\n";
					exit 0;
				}
			elsif ( ( $value >= $warn && $value < $crit ) && $backend eq "multi")
				{
					print "WARNING - $multi_obj|$multi_perf\n";
       				exit 1;
       			}
			elsif ( $value >= $crit && $backend eq "multi" )
				{
					print "CRITICAL - $multi_obj|$multi_perf\n";
        			exit 2;
				}
		}
	elsif ( $warn > $crit)
		{
			# print "3\n";				# for debuggin only
			if ( $perf_value > $warn && ($backend eq "abap" || $backend eq "trex"))
				{
        			print "OK - $obj $perf_value"."$perf_unit|$obj=$perf_value"."$perf_unit\n";
        			exit 0;
       			}
			elsif ( ($perf_value <= $warn && $perf_value > $crit) && ($backend eq "abap" || $backend eq "trex") )
				{
        			print "WARNING - $obj $perf_value"."$perf_unit|$obj=$perf_value"."$perf_unit\n";
       				exit 1;
       			}
			elsif ( $perf_value <= $crit && ($backend eq "abap" || $backend eq "trex"))
				{
    				print "CRITICAL - $obj $perf_value"."$perf_unit|$obj=$perf_value"."$perf_unit\n";
        			exit 2;
				}
			elsif ( $greatest > $warn && $backend eq "java" )
				{
        			print "OK - @other|@other\n";
        			exit 0;
       			}
			elsif ( ( $greatest <= $warn && $greatest > $crit) && $backend eq "java" )
				{
        			print "WARNING - @other|@other\n";
       				exit 1;
       			}
			elsif ( $greatest <= $crit && $backend eq "java" )
				{
    				print "CRITICAL - @other|@other\n";
        			exit 2;
				}
			elsif ( $value > $warn && $backend eq "multi" )
				{
					print "OK - $multi_obj|$multi_perf\n";
					exit 0;
				}
			elsif ( ( $value <= $warn && $value > $crit ) && $backend eq "multi")
				{
					print "WARNING - $multi_obj|$multi_perf\n";
       				exit 1;
       			}
			elsif ( $value <= $crit && $backend eq "multi" )
				{
					print "CRITICAL - $multi_obj|$multi_perf\n";
        			exit 2;
				}
		}
}

sub plugin_timeout{
	print "Critical -> Plugin wegen Timeout abgebrochen. Bitte kontrollieren!\n";
    exit 2;
	}
	
sub help{
	if ( $help == "1" ) 
			{
			print "\n";
			print "Usage:\n";
			print "	check_host_ctrl.pl -host <HOSTNAME only with local sapcontrol> -sysnr <SAP-SYS-NR> -meth <sap|nag|ls|cons> -<obj|function> <MONITORING-OBJEKT> -backend <abap|java|trex|multi> -w <WARNING-LEVEL> -c <CRITICAL-LEVEL> -t <TIME_IN_SEC> -sudo <0|1>\n";
			print "\n";
			print "Optionen:\n";
			print "\n";
			print "	-host: HOSTNAME\n";
			print "\n";
			print "	-sysnr: SAP-System-NR\n";
			print "\n";
			print "\n";
			print "	-meth: <sap|nag|ls|cons>\n";
			print "		sap:	The alarmlevels are used from sap-ccms-methode ta:rz20. The SAP-LEVEL are GREEN, YELLOW, RED, GRAY.\n";
			print "		nag:	The alarmlevel warning or critical are used from nagios. This options are -w (warning) and -c (critical).\n";
			print "		ls:	List the monitoring tree with all objects.\n";
			print "		cons:	You can use other objects without ccms. For more information use sapcontrol -h.\n";
			print "\n";
			print "	-obj: <MONITORING-OBJECT>\n";
			print "		abap ->\n";
			print "			Operating-System:\n";
			print "			Free Memory 			-> Free Memory OS\n";
			print "			Paging\\Page_In			-> PageIn\n";
			print "			Paging\\Page_Out			-> PageOut\n";
			print "			Swap_Space\\Percentage_Used	-> SWAP Space usage %\n";
			print "\n";
			print "			SAP:\n";
			print "			Utilisation Granule Entries 	-> DE: Sperrtabelle\n";
			print "			Gateway_CommAdmEnty	-> DE: SAP Gateway Verbindungen\n";
			print "			PerformanceU1\\Utilisation		-> Performance UPD1\n";
			print "			OS_Collector\\State		-> OS Collector State\n";
			print "			CacheHits			-> CacheHits %\n";
			print "			CacheHitsMem			-> CacheHitsMem %\n";
			print "			ResponseTime			-> Dialog Response Time msec\n";
			print "			FrontendResponseTime		-> Frontend Response Time msec\n";
			print "			UsersLoggedIn			-> Number of Users logged in\n";
			print "			LDAP_RFC-01\\Status		-> LDAP Connector 01 State\n";			
			print "			EM Used				-> Extended Memory Usage %\n";
			print "			R3RollUsed			-> Roll area usage %\n";
			print "			Shortdumps			-> ABAP Shortdumps st22. You should use with -obj: sap\n";
			print "			Shortdumps Frequency		-> ABAP Shutdump frequenze\n";
			print "			deadlocks			-> deadlocks\n";
			print "			HostspoolListUsed		-> Used Spool Numbers %\n";
			print "			SyslogFreq			-> Syslogfrequency %\n";
			print "			R3Syslog\\Security		-> Syslog analysis scope: security messages\n";
			print "			R3Syslog\\CCMS			-> Syslog analysis scope: ccms messages\n";
			print "\n";
			print "			DB:\n";
			print "			DBRequestTime			-> RequestTime\n";
			print "			SqlError			-> SQL-Error\n";
			print "\n";
			print "		java ->\n";
			print "			HTTPConnectionsCount		-> dispatcher http connections\n";
			print "			Average response time		-> msec. DE: durchschnittliche Antwortzeit\n";
			print "			UsedMemoryRate			-> Memory Usage\n";
			print "			UnsuccessfulLogonAttemptsCount	-> Unsuccessful Logons\n";
			print "			CurrentHttpSessions		-> act. http sessions\n";
			print "\n";
			print "		trex ->\n";
			print "			Free Memory			-> Free Memory \%\n";
			print "			IndexServer Memory		-> Index Server Memory\n";
			print "			QueueServer Memory		-> Queue Server Memory\n";
			print "			RfcServer Memory		-> RFC Server Memory\n";
			print "			Build				-> TREX Version\n";
			print "			Search Time			-> Performance: Search Time\n";
			print "			Search Count			-> Performance: Request per minute\n";
			print "			RFC Check			-> RFC Connections to backend systems\n";
			print "			Index Status			-> Index State\n";
			print "			Build				-> TREX Version\n";
			print "\n";
			print "	-function: use this with -meth: cons\n";
			print "		ABAPGetWPTable -> Processtable of sap-system ( dia-proc, btc-proc, upd-proc, spo-proc, up2-proc )\n";
			print "\n";
			print "	-backend: Type of sap-backend system\n";
			print "		abap: abap-backend-system\n";
			print "		java: java-backend-system\n";
			print "		trex: trex-backend-system\n";
			print "		multi: multiline output for meth: cons\n";
			print "\n";
			print "	-w: warning-level\n";
			print "\n";
			print "	-c: Critical Level\n";
			print "\n";
			print "	-t: plugin timeout, default: 30 sec.\n";
			print "\n";
			print "	-sudo: 1\n";
			print "		This parameter is optional. You can use it if you start the sapcontrol check off remote host not on icinga-system.\n";
			print "		If you set the parameter to 1 the icinga-system check with ssh and sudo command on remote-site\n";
			print "\n";
			print "Help:\n";
			print "	Error:\n";
			print "		GetAlertTree FAIL: NIECONN_REFUSED (Connection refused), NiRawConnect failed in plugin_fopen -> The sap-system-nr is incorrect.\n";
			print "\n";
			print "		FAIL: HTTP error, HTTP/1.1 401 Unauthorized -> You use a new sap-kernel binarie. In this new version the sapstartsrv service have security features enabled.\n";
			print "		Set the paramter service/protectedwebmethods=NONE in the sap-instance profile. NONE->sapstartsrv-security-features disabled\n";
			print "		For more information have a look at SAP-Note 927637.\n"; 
			print "\n";
			print "	Others:\n";
			print "		The Check-Plugin use the sapcontrol binary (/usr/sap/hostctrl/exe/sapcontrol). The binary use the account <root> to connect to the system.\n";
			print "		This is sap-standard!\n";
			print "		You can use the sapcontrol for many things. Start,stop, monitoring and so on.....\n";
			print "\n";
			print "		I have to methodes to use this check.\n";
			print "			You can use the sapcontrol-binarie from the remote-machine.\n";
			print "				If you use this you must configure the sudo command on the remote-machine and the icinga-check is a ssh check.\n";
			print "				The check_plugin should only use with your nagios-user and check per ssh the remote-machine.\n";
			print "				This is the command ->\n";
			print "	 				sudo su - root -c /usr/sap/hostctrl/exe/sapcontrol\n";
			print "				Adv:	no software installation on the icinga-system\n";
			print "				DisAdv:	all sapchecks use a ssh-call\n";
			print "\n";
			print "				The sudo-file on the remote-machine have this entry:\n";
			print "				%nagios  ALL=(ALL)       NOPASSWD: /bin/su - root -c /usr/sap/hostctrl/exe/sapcontrol -nr * -function GetAlertTree*\n";
			print "\n";
			print "			Or you must install the hostctrl on the icinga-system.\n";
			print "				You can use the sapcontrol-binarie directly from icinga-system without ssh and sudo.\n";
			print "				That is the preferred way!!\n";
			print "\n";
			print "	Monitoring-Objects:\n";
			print "		If you want other monitoring objects from ccms, please use the command:\n";
			print "		/usr/sap/hostctrl/exe/sapcontrol -nr <SYSNR> -function GetAlertTree\n";
			print "		or\n";
			print "		check_host_ctrl.pl -host <HOSTNAME> -nr <SYSNR> -meth ls\n";
			print "		to investigate which objects are available.\n";
			print "\n";
			print "Version: check_host_ctrl.pl -v\n";
			print "\n";
			print "Syntax: check_host_ctrl.pl -host <hostname> -sysnr <SAP-SYS-NR> -meth <sap|nag|ls|cons> -<obj|function> <OBJEKT> -backend <abap|java|trex|multi> -w <WARNING-LEVEL> -c <CRITICAL-LEVEL> -t <TIME_IN_SEC>\n";
			print "\n";
			print "Examples:\n";
			print "\n";
			print "	check_host_ctrl.pl -host <host> -sysnr 00 -meth ls\n";
			print "		List all montoring-objects from the backend\n";
			print "\n";
			print "	check_host_ctrl.pl -host <host> -sysnr 00 -meth ls -sudo 1\n";
			print "		List all monitoring-objects from backend, but use the sapcontrol binarie from backend-system with ssh connection and sudo command\n";
			print "\n";
			print "	check_host_ctrl.pl -host <host> -sysnr 00 -meth sap -obj CacheHits -backend abap\n";
			print "		Output of sap-abap cachehits\n";
			print "\n";
			print "	check_host_ctrl.pl -host <host> -sysnr 00 -meth nag -obj CacheHits -backend abap -w 60 -c 80\n";
			print "		Output of sap-abap cachehits with alarmlevel from nagios-system\n";
			print "\n";
			print "	check_host_ctrl.pl -host <host> -sysnr 00 -meth cons -function ABAPGetWPTable -backend multi -w 80 -c 90\n";
			print "		Output of sap-processes, DIA-Usage, BTC-Usage, SPO-Usage, UPD-Usage, UP2-Usage\n";
			print "\n";
	}
}

sub version{
		if ( $ver == "1" )
			{
				print "\n";
				print "Version: \n";
				print "	0.1 -> add abap-instances....\n";
				print "	0.2 -> add java-server (SAP-Rel. 7.01) with more then one servernodes per instance, add trex-server\n";
				print "	0.3 -> correct nagios alarmroutine and add methode ls\n";
				print "	0.4 -> use getopt::long, precheck sysnr and monitoring object\n";
				print "	0.4.1 -> sapctrl command with global-var\n";
				print "	0.5 -> change pnp performance values for abap-systems\n";
				print "	0.5.1 -> change output values for java-systems, correct performance outout for java servernodes\n";
				print "		-> correct sap-output gray, trex monitoring extended\n";
				print "	0.5.2 -> correction of abap shortdump\n";
				print "	0.5.3 -> change sapcontrol-output from list to script, use sapcontrol with ssh on remote-machine or with hostctrl-client on icinga-host\n";
				print "	0.5.4 -> ssh bug in precheck routine\n";
				print "	0.5.5 -> change sub sapctrl for performance value and unit\n";
				print "		-> you must use with meth=nag a warning and critical level\n";
				print "		-> add backend-type: multi -> use for multiline output\n";
				print "		-> add meth-type: cons with -function ABAPGetWPTable\n";
				print "		-> add a new message about message 'not authorized output'\n";
				print "		-> change sub sapctrl grep option from -F to -w\n";
				print "		-> we found sap-systems without up2 processes, now we check the number of up2 processes\n";
				print "	0.5.6 -> add runtime values for Dialog, Batch, Spool, Update and Update2 processes. Now only the running processes are counted with have reached the runtime value.\n";
				print "		-> The runtime value can configured in the my conf section\n";
				print "\n";
				print "For changes, ideas or bugs please contact kutte013\@gmail.com\n";
				print "\n";
				exit 0;
			}
	}
