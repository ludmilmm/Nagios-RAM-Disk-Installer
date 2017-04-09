#!/bin/bash

############### RAM Disk Installer ################

# Copyright (C) 2010-2014 Nagios Enterprises, LLC
# Version 1.2 - 11/24/2015

# Questions/issues should be posted on the Nagios
# Support Forum at https://support.nagios.com/forum/

# Feedback/recommendations/tips can be sent to
# Ludmil Miltchev at lmiltchev@nagios.com                
 
###################################################

# Setting some colors
red='\033[0;31m'
green='\033[0;32m'
cyan='\033[0;36m'
nocolor='\033[0m' # No Color

# Error messages
NOTROOTERR="This script needs to be run as root/superuser. Exiting..."
CONFIGERR="Config errors found. Exiting..."
OLDRAMDISKERR="Old RAM Disk found... Exiting..."
OLDINITNAGIOSERR="This "/etc/init.d/nagios" script is old. Upgrade Nagios XI or install RAM disk manually. Exiting..."

# Defining variables and functions
RAMDISKDIR=/var/nagiosramdisk
INITNAGIOS=/etc/init.d/nagios
INITNPCD=/etc/init.d/npcd
NAGIOSCFG=/usr/local/nagios/etc/nagios.cfg
NRDPSERPHP=/usr/local/nrdp/server/config.inc.php
HTMLPHP=/usr/local/nagiosxi/html/config.inc.php
NAGIOSMOBILEPHP=/usr/local/nagiosmobile/include.inc.php
NCPDCFG=/usr/local/nagios/etc/pnp/npcd.cfg
FSTAB=/etc/fstab
BACKUPDIR=/tmp/ramdiskbackup
SYSCONFIGNAGIOS=/etc/sysconfig/nagios

USERID () {
if [ $(id -u) -ne 0 ]; then
	echo -e "${red}$1${nocolor}"
	exit 1
fi
}

# Checking exit status
CHKEXITSTAT () {
if [ $? -ne 0 ]; then
	echo ""
	echo -e "${red}$1${nocolor}"
	echo ""
	exit 1
fi
}

# Check distro version
ver=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))

# Setting the RAM Disk size
IFNUMBER () {
read -e -i $RECSIZE -p "How big of a RAM Disk would you like? Please, enter an integer or just hit 'Enter' to accept the default size ->  " THESIZE
}

###################################################################################################################################################

echo -e "${red}======================================== IMPORTANT! ========================================${nocolor}"
        
echo -e "${green}This script automates the process of setting up a RAM Disk in Nagios XI.

If you don't want to install RAM Disk automatically, you could exit the script and install
it manually, however keep in mind that manual setup of RAM Disk will be a bit more involved.${nocolor}"
echo -e "${red}============================================================================================${nocolor}
"
read -p "Do you want to continue with automatic install? [Y/n] " AUTO

        case "$AUTO" in
                "[yY][eE][sS]" | "y" | "Y" | "")
                        echo "Proceeding with setting up RAM Disk in Nagios XI..."
                        ;;
                *)
                        echo "Installation cancelled!"
			echo "To install RAM Disk manually, please follow this document:"
			echo -e "${cyan}http://assets.nagios.com/downloads/nagiosxi/docs/Utilizing_A_RAM_Disk_In_NagiosXI.pdf${nocolor}"
                        exit 0
        esac

# Checking if we have sufficient privileges
USERID "$NOTROOTERR"

# Checking for old/incomplete RAM Disk installs
echo "Checking for existing RAM Disk..."
if [ -d $RAMDISKDIR ] || grep nagiosramdisk $INITNAGIOS || grep nagiosramdisk $INITNPCD || grep nagiosramdisk $NAGIOSCFG || grep nagiosramdisk $NRDPSERPHP || grep nagiosramdisk $HTMLPHP || grep nagiosramdisk $NCPDCFG || grep nagiosramdisk $FSTAB ; then
	echo ""
        echo -e "${red}$OLDRAMDISKERR${nocolor}"
	echo ""
	exit 1
else
        echo "Old RAM Disk not found... Countinuing with the install..."
fi

# Checking for old nagios init script
if grep -q USE_RAMDISK $INITNAGIOS; then
	echo ""
	echo "Correct version of nagios init script found. Countinuing with the install..."
	echo ""	
else
	echo -e "${red}$OLDINITNAGIOSERR${nocolor}"
	exit 1
fi

# Making sure there are not config errors before we get started
echo "Checking for config errors..."
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
CHKEXITSTAT "$CONFIGERR"

# Backup configs prior to the RAM Disk install (just in case)
echo "Backing up configs in $BACKUPDIR..."
mkdir -p $BACKUPDIR
cd $BACKUPDIR
tar -czvf cfgbackup.tar.gz $INITNAGIOS $INITNPCD $NAGIOSCFG $NRDPSERPHP $HTMLPHP $NCPDCFG $NAGIOSMOBILEPHP

# Determining the recommended size of the RAM Disk based on the total number of hosts + services
# < 1000	--->	RAM Disk size = 100MB
# 1000-5000	--->	RAM Disk size = 300MB
# > 5000	--->	RAM Disk size = 500MB 

NUMHOSTS=$(/usr/local/nagios/bin/nagiostats|grep "Total Hosts"|awk '{ print $3 }')
NUMSERVICES=$(/usr/local/nagios/bin/nagiostats|grep "Total Services"|awk '{ print $3 }')
TOTALSIZE=$(($NUMHOSTS + $NUMSERVICES))

if [ $TOTALSIZE -lt 1000 ]; then
        RECSIZE=100
elif [ $TOTALSIZE -gt 1000 ] && [ $TOTALSIZE -lt 5000 ]
then
        RECSIZE=300
else
	RECSIZE=500
fi

echo "We recommend a RAM Disk of $RECSIZE MB."

IFNUMBER

while true; do
USERNUM="^[0-9]+$"
if ! [[ $THESIZE =~ $USERNUM ]]; then
	echo ""
        echo -e "${red}Please, enter a valid number!${nocolor}"
	echo ""
        IFNUMBER
else
        echo "Setting up RAM Disk size = $THESIZE MB"
        break
fi
done

# Modifying configs.
echo "Modifying configs..."

# Creating /etc/sysconfig/nagios
touch $SYSCONFIGNAGIOS
chown nagios:nagios $SYSCONFIGNAGIOS
chmod 775 $SYSCONFIGNAGIOS
echo -e "USE_RAMDISK=1\nRAMDISK_DIR=/var/nagiosramdisk\nRAMDISK_SIZE=${THESIZE}\nif [ \"\`mount |grep \"\${RAMDISK_DIR} type tmpfs\"\`\"X == \"X\" ]; then\n   mount -t tmpfs -o size=\${RAMDISK_SIZE}m tmpfs \${RAMDISK_DIR}\nfi\nmkdir -p -m 775 \${RAMDISK_DIR} \${RAMDISK_DIR}/tmp \${RAMDISK_DIR}/spool \${RAMDISK_DIR}/spool/checkresults \${RAMDISK_DIR}/spool/xidpe \${RAMDISK_DIR}/spool/perfdata\nchown -R nagios:nagios \${RAMDISK_DIR}" > $SYSCONFIGNAGIOS

if [ "$ver" = "6" ] || [ "$ver" = "6Server" ]; then
	$INITNAGIOS restart
	$INITNPCD restart
else
	systemctl enable nagios.service
	systemctl restart nagios.service
	systemctl enable npcd.service
	systemctl restart npcd.service
fi

# Modifying /usr/local/nagios/etc/nagios.cfg
sed -i '/service_perfdata_file=/c\service_perfdata_file=/var/nagiosramdisk/service-perfdata' $NAGIOSCFG
sed -i '/host_perfdata_file=/c\host_perfdata_file=/var/nagiosramdisk/host-perfdata' $NAGIOSCFG
sed -i '/check_result_path=/c\check_result_path=/var/nagiosramdisk/spool/checkresults' $NAGIOSCFG
sed -i '/object_cache_file=/c\object_cache_file=/var/nagiosramdisk/objects.cache' $NAGIOSCFG
sed -i '/status_file=/c\status_file=/var/nagiosramdisk/status.dat' $NAGIOSCFG
sed -i '/temp_path=/c\temp_path=/var/nagiosramdisk/tmp' $NAGIOSCFG

# Modifying /usr/local/nagiosmobile/include.inc.php

sed -i '/$STATUS_FILE/c\$STATUS_FILE  = "/var/nagiosramdisk/status.dat";' $NAGIOSMOBILEPHP
sed -i '/$OBJECTS_FILE/c\$OBJECTS_FILE = "/var/nagiosramdisk/objects.cache";' $NAGIOSMOBILEPHP

# Modifying /usr/local/nrdp/server/config.inc.php
sed -i '/check_results_dir/c\$cfg["check_results_dir"]="/var/nagiosramdisk/spool/checkresults";' $NRDPSERPHP

# Modifying /usr/local/nagiosxi/html/config.inc.php
sed -i "/xidpe_dir/c\$cfg\[\'xidpe_dir\'\] = \'/var/nagiosramdisk/spool/xidpe/\';" $HTMLPHP
sed -i "/perfdata_spool/c\$cfg\[\'perfdata_spool\'\] = \'/var/nagiosramdisk/spool/perfdata/\';" $HTMLPHP

# Modifying /usr/local/nagios/etc/pnp/npcd.cfg
sed -i "/perfdata_spool_dir = \//c\perfdata_spool_dir = /var/nagiosramdisk/spool/perfdata/" $NCPDCFG

# Modifying the 'process-host-perfdata-file-bulk' and the 'process-service-perfdata-file-bulk' commands
cat > /usr/local/nagios/etc/import/commands.cfg << EOF
define command {
       command_name                             process-host-perfdata-file-bulk
       command_line                             /bin/mv /var/nagiosramdisk/host-perfdata /var/nagiosramdisk/spool/xidpe/\$TIMET\$.perfdata.host
}
define command {
       command_name                             process-service-perfdata-file-bulk
       command_line                             /bin/mv /var/nagiosramdisk/service-perfdata /var/nagiosramdisk/spool/xidpe/\$TIMET\$.perfdata.service
}
EOF

# Making sure "/usr/local/nagiosxi/var/subsys/" directory is owned by nagios
chown -R nagios:nagios /usr/local/nagiosxi/var/subsys/

# Running reconfigure_nagios.sh and restarting services

echo "Reconfiguring nagios..."
cd /usr/local/nagiosxi/scripts
./reconfigure_nagios.sh
sleep 3

if [ "$ver" = "6" ] || [ "$ver" = "6Server" ]; then
	/etc/init.d/httpd restart
	/etc/init.d/npcd restart
else
	systemctl restart httpd.service
	systemctl restart npcd.service		
fi

echo -e "
${green}All done!
Old configs were backed up in $BACKUPDIR 
RAM Disk was installed in $RAMDISKDIR
The RAM Disk size was set to $THESIZE MB${nocolor}
"