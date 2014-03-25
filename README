The Check-Plugin use the sapcontrol binary (/usr/sap/hostctrl/exe/sapcontrol). The binary use the account <root> to connect to the system.
This is sap-standard!
You can use the sapcontrol for many things. Start,stop, monitoring and so on.....
The check_plugin should only use with your nagios-user and check per ssh the remote-machine.

This is the command in sudoers-file ->
	sudo su - root -c /usr/sap/hostctrl/exe/sapcontrol

The sudo-file on the remote-machine have this entry:\n";
	%nagios  ALL=(ALL)       NOPASSWD: /bin/su - root -c /usr/sap/hostctrl/exe/sapcontrol -nr * -function GetAlertTree*

You can use the the check_sap_hostctrl -h for help.

