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
	timedef		=> "30",
	sudo 		=> "/usr/bin/sudo su - root -c",
	sapcontrol 	=> "/usr/sap/hostctrl/exe/sapcontrol",
	ps		=> "/bin/ps -ef",
	usrbin		=> "/usr/bin",
	);


#
# Dont change anything below these lines ...
#


GetOptions(
    "v"         => \$ver,
    "version"   => \$ver,
    "h"         => \$help,
    "help"      => \$help,
    "sysnr=i"	=> \$sysnr,
    "meth=s"    => \$meth,
    "obj=s"     => \$obj,
    "backend=s" => \$backend,
    "warn=o"    => \$warn,
    "crit=o" 	=> \$crit,
    "t=i"       => \$timec,
    "time=i" 	=> \$timec,
	);


version();
help();
timeout();
        

# timeout routine
$SIG{ALRM} = \&plugin_timeout;
eval {
		alarm ($timeout);
        };
    
    
    
    
# precheck
precheck();    

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
	sapctrl();
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
		#print "methode -> ls\n";
		sapctrl_ls();
	}
	
	
	
sub precheck{
	# sapstartsrv must running to use the binary sapsontrol. sapstartsrv starts with systemstart.
	#print "precheck\n";
	@startsrv_run = `$conf{ps}`;
	chomp $startsrv_run[0];
	@gstartsrv = grep /.*sapstartsrv.*$sysnr.*/, @startsrv_run;
	chomp $gstartsrv[0];
	#print "$gstartsrv[0]\n";
	if ( $gstartsrv[0] ne "undev" )
		{
			#print "sapstartsrv is working..\n";
			$chk_sysnr = `$conf{sudo} "$conf{sapcontrol} -nr $sysnr -function GetProcessList"`;
			$rc_chk_sysnr = $?;
			chomp $chk_sysnr;
			#print "$rc_chk_sysnr\n";
			if ( $rc_chk_sysnr eq "256" )
				{
					print "UNKNOWN - Please check the -sysnr parameter.\n";
					exit 3;
				}
		}
	}

sub sapctrl{
	my $command = `$conf{sudo} "$conf{sapcontrol} -nr $sysnr -function GetAlertTree | $conf{usrbin}/grep -F '$obj'"`;
	$rc_command = $?;
	chomp $command;
	chomp $rc_command;
	@command_split = split /,/, $command;
	$command_split[2] =~ s/ //;			# sap returncode (green, yellow, red, gray)
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
	
sub sapctrl_ls{
	if ( $meth eq "ls" )
			{
				my $command = `$conf{sudo} "$conf{sapcontrol} -nr $sysnr -function GetAlertTree"`;
				#print "$command\n";
				my @command_split = split /\n/, $command;
				$stanza = @command_split;
				#print "count: $stanza\n";
				$b = 10;
				for ( $i=0; $i<$stanza; $i++)
					{
						my @outsplit = split /,/, $command_split[$b];
						my @advsplit = split /;/, $outsplit[5];
						print "Pos.0->Monitoring object, Pos.2->SAP Alarmlevel, Pos.3->Value; Pos.72->Advanced-Value\n";
						print "Pos.0->$outsplit[0], Pos.2->$outsplit[2], Pos.3->$outsplit[3]; Pos.72->$advsplit[71]\n";
						#print "ADV->@advsplit\n";
						#print "ADV1->$advsplit[71]\n";
						#$lenght = @advsplit;
						#print "laenge -> $lenght\n";
						print "sap-output:\n";
						print "$command_split[$b]\n";
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
			if ( $command_split[3] < $warn && ($backend eq "abap" || $backend eq "trex") )
				{
					print "OK - $obj $command_split[3]|$obj=$command_split[3]\n";
        			exit 0;
       			}
			elsif ( ($command_split[3] >= $warn && $command_split[3] < $crit ) && ($backend eq "abap" || $backend eq "trex"))
				{
					print "WARNING - $obj $command_split[3]|$obj=$command_split[3]\n";
       				exit 1;
       			}
			elsif ( $command_split[3] >= $crit && ($backend eq "abap" || $backend eq "trex") )
				{
					print "CRITICAL - $obj $command_split[3]|$obj=$command_split[3]\n";
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
		}
	elsif ( $warn > $crit)
		{
			if ( $command_split[3] > $warn && ($backend eq "abap" || $backend eq "trex"))
				{
        			print "OK - $obj $command_split[3]|$obj=$command_split[3]\n";
        			exit 0;
       			}
			elsif ( ($command_split[3] <= $warn && $command_split[3] > $crit) && ($backend eq "abap" || $backend eq "trex") )
				{
        			print "WARNING - $obj $command_split[3]|$obj=$command_split[3]\n";
       				exit 1;
       			}
			elsif ( $command_split[3] <= $crit && ($backend eq "abap" || $backend eq "trex"))
				{
    				print "CRITICAL - $obj $command_split[3]|$obj=$command_split[3]\n";
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
			print "	check_host_ctrl.pl -sysnr <SAP-SYS-NR> -meth <sap|nag|ls> -obj <MONITORING-OBJEKT> -backend <abap|java|trex> -w <WARNING-LEVEL> -c <CRITICAL-LEVEL> -t <TIME_IN_SEC>\n";
			print "\n";
			print "Optionen:\n";
			print "\n";
			print "	-sysnr: SAP-System-NR";
			print "\n";
			print "\n";
			print "	-meth: <sap|nag|ls>\n";
			print "		sap:	The alarmlevels are used from sap-ccms-methode ta:rz20. The SAP-LEVEL are GREEN, YELLOW, RED, GRAY.\n";
			print "		nag:	The alarmlevel warning or critical are used from nagios. This options are -w (warning) and -c (critical).\n";
			print "		ls:	List the monitoring tree with all objects.\n";
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
			print "			LDAP_RFC-02\\Status		-> LDAP Connector 02 State\n";
			print "			LDAP_RFC-03\\Status		-> LDAP Connector 03 State\n";
			print "			LDAP_RFC-04\\Status		-> LDAP Connector 04 State\n";
			print "			LDAP_RFC-05\\Status		-> LDAP Connector 05 State\n";
			print "			LDAP_RFC-06\\Status		-> LDAP Connector 06 State\n";
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
			print "	-backend: Type of sap-backend system\n";
			print "		abap: abap-backend-system\n";
			print "		java: java-backend-system\n";
			print "		trex: trex-backend-system\n";
			print "\n";
			print "	-w: warning-level\n";
			print "\n";
			print "	-c: Critical Level\n";
			print "\n";
			print "	-t: plugin timeout, default: 30 sec.\n";
			print "\n";
			print "Help:\n";
			print "	Error:\n";
			print "		GetAlertTree FAIL: NIECONN_REFUSED (Connection refused), NiRawConnect failed in plugin_fopen -> The sap-system-nr is incorrect.\n";
			print "\n";
			print "	Others:\n";
			print "		The Check-Plugin use the sapcontrol binary (/usr/sap/hostctrl/exe/sapcontrol). The binary use the account <root> to connect to the system.\n";
			print "		This is sap-standard!\n";
			print "		You can use the sapcontrol for many things. Start,stop, monitoring and so on.....\n";
			print "		The check_plugin should only use with your nagios-user and check per ssh the remote-machine.\n";
			print "		This is the command ->\n";
			print "	 		sudo su - root -c /usr/sap/hostctrl/exe/sapcontrol\n";
			print "\n";
			print "		The sudo-file on the remote-machine have this entry:\n";
			print "			%nagios  ALL=(ALL)       NOPASSWD: /bin/su - root -c /usr/sap/hostctrl/exe/sapcontrol -nr * -function GetAlertTree*\n";
			print "\n";
			print "	Monitoring-Objects:\n";
			print "		If you want other monitoring objects you can use on the sap-system the command:\n";
			print "		/usr/sap/hostctrl/exe/sapcontrol -nr <SYSNR> -function GetAlertTree\n";
			print "		or\n";
			print "		check_host_ctrl.pl -nr <SYSNR> -meth ls\n";
			print "		to investigate which objects are available.\n";
			print "\n";
			print "Version: check_host_ctrl.pl -v\n";
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
				print "	      -> correct sap-output gray, trex monitoring extended\n";
				print "	0.5.2 -> correction of abap shortdump, meth: ls extended\n";
				print "\n";
				print "For changes, ideas or bugs please contact kutte013\@gmail.com\n";
				print "\n";
				exit 0;
			}
	}
