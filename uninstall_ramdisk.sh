#!/bin/bash

############### RAM Disk Uninstaller ################

# Copyright (C) 2010-2014 Nagios Enterprises, LLC
# Version 2.2 - 09/24/2024

# Questions/issues should be posted on the Nagios
# Support Forum at https://support.nagios.com/forum/

# Feedback/recommendations/tips can be sent to
# Ludmil Miltchev at lmiltchev@nagios.com

#####################################################

# Setting some colors
red='\033[0;31m'
green='\033[0;32m'
cyan='\033[0;36m'
nocolor='\033[0m' # No Color

# Error messages
NOTROOTERR="This script needs to be run as root/superuser. Exiting..."
CONFIGERR="Config errors found. Exiting..."

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
SYSCONFIGDIR=/etc/sysconfig
SYSCONFIGNAGIOS=/etc/sysconfig/nagios
SYSTEMD=/lib/systemd/system
XIRELEASE=`grep -w "release" /usr/local/nagiosxi/var/xiversion | cut -d '=' -f2`

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

# Mobile function
MOBILE () {
if [ $XIRELEASE -lt "50700" ]; then        
        sed -i '/$STATUS_FILE/c\$STATUS_FILE  = "/usr/local/nagios/var/status.dat";' $NAGIOSMOBILEPHP
		sed -i '/$OBJECTS_FILE/c\$OBJECTS_FILE = "/usr/local/nagios/var/objects.cache";' $NAGIOSMOBILEPHP
fi
}

# Backup function
BACKUP () {
	echo "Backing up configs in $BACKUPDIR..."
	mkdir -p $BACKUPDIR
	cd $BACKUPDIR
	if [ $XIRELEASE -lt "50700" ]; then
		tar -czvf cfgbackup.tar.gz $INITNPCD $NAGIOSCFG $NRDPSERPHP $HTMLPHP $NCPDCFG $NAGIOSMOBILEPHP
	else
		tar -czvf cfgbackup.tar.gz $INITNPCD $NAGIOSCFG $NRDPSERPHP $HTMLPHP $NCPDCFG
	fi
}

# Get settings from xi-sys.cfg which give us the OS & version
. /usr/local/nagiosxi/var/xi-sys.cfg

# Determine if sysv or systemd is in use
if [ "$distro" = "CentOS" ] || [ "$distro" = "Rocky" ] || [ "$distro" = "RedHatEnterpriseServer" ] || [ "$distro" = "OracleServer" ] || [ "$distro" = "CloudLinux" ]; then
  if [ "$ver" = "8" ] || [ "$ver" = "9" ]; then
    SYSTEM="SYSTEMD"
  else
    SYSTEM="SYSV"
  fi
elif [ "$distro" = "Ubuntu" ]; then
  if [ "$ver" = "20" ] || [ "$ver" = "22" ] || [ "$ver" = "24" ]; then
    SYSTEM="SYSTEMD"
  else
    SYSTEM="SYSV"
  fi
elif [ "$distro" = "Debian" ]; then
    SYSTEM="SYSTEMD"  
else
    echo -e "${red}$DISTROVERSIONERR${nocolor}"
  exit 1
fi


###################################################################################################################################################

echo -e "${red}=============================== IMPORTANT! ===============================${nocolor}"

echo -e "${green}This script will remove RAM Disk from Nagios XI.

If you din't use the automathic method (the 'install_ramdisk.sh' script)
to install RAM Disk in Nagios XI, you would need to uninstall it manually.${nocolor}"
echo -e "${red}==========================================================================${nocolor}
"
read -p "Do you want to continue with automatic RAM disk removal? [Y/n] " AUTO

        case "$AUTO" in
                "[yY][eE][sS]" | "y" | "Y" | "")
                        echo "Proceeding with automatic RAM Disk removal in Nagios XI..."
                        ;;
                *)
                        echo "Automatic removal of RAM Disk was cancelled!"
                        echo "To uninstall RAM Disk manually, undo the changes you made while installing it."
                        exit 0
        esac

# Checking if we have sufficient privileges
USERID "$NOTROOTERR"

# Making sure there are not config errors before we get started
echo "Checking for config errors..."
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
CHKEXITSTAT "$CONFIGERR"

# Backup configs prior to uninstalling RAM Disk (just in case)
BACKUP

# Restoring configs.
echo "Restoring configs..."

# Restoring /usr/local/nagios/etc/nagios.cfg
sed -i '/service_perfdata_file=/c\service_perfdata_file=/usr/local/nagios/var/service-perfdata' $NAGIOSCFG
sed -i '/host_perfdata_file=/c\host_perfdata_file=/usr/local/nagios/var/host-perfdata' $NAGIOSCFG
sed -i '/check_result_path=/c\check_result_path=/usr/local/nagios/var/spool/checkresults' $NAGIOSCFG
sed -i '/object_cache_file=/c\object_cache_file=/usr/local/nagios/var/objects.cache' $NAGIOSCFG
sed -i '/status_file=/c\status_file=/usr/local/nagios/var/status.dat' $NAGIOSCFG
sed -i '/temp_path=/c\temp_path=/tmp' $NAGIOSCFG
sed -i '/temp_file=/c\temp_path=/usr/local/nagios/var/nagios.tmp' $NAGIOSCFG

# Restoring /usr/local/nagiosmobile/include.inc.php (if the "old" mobile interface is used)
MOBILE

# Restoring /usr/local/nrdp/server/config.inc.php
sed -i '/check_results_dir/c\$cfg["check_results_dir"]="/usr/local/nagios/var/spool/checkresults";' $NRDPSERPHP

# Restoring /usr/local/nagiosxi/html/config.inc.php
sed -i "/xidpe_dir/c\$cfg\[\'xidpe_dir\'\] = \'/usr/local/nagios/var/spool/xidpe/\';" $HTMLPHP
sed -i "/perfdata_spool/c\$cfg\[\'perfdata_spool\'\] = \'/usr/local/nagios/var/spool/perfdata/\';" $HTMLPHP

# Restoring /usr/local/nagios/etc/pnp/npcd.cfg
sed -i "/perfdata_spool_dir = \//c\perfdata_spool_dir = /usr/local/nagios/var/spool/perfdata/" $NCPDCFG

# Removing /etc/sysconfig/nagios and unmounting /var/nagiosramdisk

if [ "$SYSTEM" = "SYSV" ]; then
        rm -f $SYSCONFIGNAGIOS
        service nagios restart
        service npcd restart    
        umount $RAMDISKDIR
else        
        systemctl stop ramdisk.service
		systemctl disable ramdisk.service
		rm -f $SYSTEMD/ramdisk.service
		systemctl daemon-reload
        systemctl restart nagios.service
        systemctl restart npcd.service
        umount $RAMDISKDIR
fi

# Removing the /var/nagiosramdisk directory
rm -rf $RAMDISKDIR

# Restoring the 'process-host-perfdata-file-bulk' and the 'process-service-perfdata-file-bulk' commands
cat > /usr/local/nagios/etc/import/commands.cfg << EOF
define command {
       command_name                             process-host-perfdata-file-bulk
       command_line                             /bin/mv /usr/local/nagios/var/host-perfdata /usr/local/nagios/var/spool/xidpe/\$TIMET\$.perfdata.host
}
define command {
       command_name                             process-service-perfdata-file-bulk
       command_line                             /bin/mv /usr/local/nagios/var/service-perfdata /usr/local/nagios/var/spool/xidpe/\$TIMET\$.perfdata.service
}
EOF

# Running reconfigure_nagios.sh and restarting services

echo "Reconfiguring nagios..."
cd /usr/local/nagiosxi/scripts
./reconfigure_nagios.sh
sleep 3

if [ "$SYSTEM" = "SYSV" ]; then
       service httpd restart
       service npcd restart
else
       systemctl restart httpd.service
       systemctl restart npcd.service
fi

echo -e "
${green}All done!
RAM Disk was uninstalled successfully.
Old configs were backed up in $BACKUPDIR.${nocolor}
"
