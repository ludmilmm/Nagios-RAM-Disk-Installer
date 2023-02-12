#!/bin/bash
############### RAM Disk Installer ################
# Copyright (C) 2010-2018 Nagios Enterprises, LLC
# Version 2.0 - 02/12/2023
# Questions/issues should be posted on the Nagios
# Support Forum at https://support.nagios.com/forum/
# Feedback/recommendations/tips can be sent to
# Ludmil Miltchev at lmiltchev@nagios.com              
 
###################################################
# Setting some colors
red='\033[0;31m'
green='\033[0;32m'
cyan='\033[0;36m'
nocolor='\033[0m'

# Error messages
NOTROOTERR="This script needs to be run as root/superuser. Exiting..."
CONFIGERR="Config errors found. Exiting..."
DISTROVERSIONERR="Unsupported distro or version number. Exiting..."

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
XIMINORVERSION=`grep full /usr/local/nagiosxi/var/xiversion | cut -d '=' -f2 | cut -d '.' -f2`
XIMAJORVERSION=`grep full /usr/local/nagiosxi/var/xiversion | cut -d '=' -f2 | cut -d '.' -f1`

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
if [ $XIMINORVERSION -lt "7" ] && [ $XIMAJORVERSION -lt "6" ]; then        
        sed -i '/$STATUS_FILE/c\$STATUS_FILE  = "/var/nagiosramdisk/status.dat";' $NAGIOSMOBILEPHP
        sed -i '/$OBJECTS_FILE/c\$OBJECTS_FILE = "/var/nagiosramdisk/objects.cache";' $NAGIOSMOBILEPHP
fi
}

# Backup function
BACKUP () {
    echo "Backing up configs in $BACKUPDIR..."
    mkdir -p $BACKUPDIR
    cd $BACKUPDIR
    if [ $XIMINORVERSION -lt "7" ] && [ $XIMAJORVERSION -lt "6" ]; then
        tar -czvf cfgbackup.tar.gz $INITNPCD $NAGIOSCFG $NRDPSERPHP $HTMLPHP $NCPDCFG $NAGIOSMOBILEPHP
    else
        tar -czvf cfgbackup.tar.gz $INITNPCD $NAGIOSCFG $NRDPSERPHP $HTMLPHP $NCPDCFG
    fi
}

# Get settings from xi-sys.cfg which give us the OS & version
. /usr/local/nagiosxi/var/xi-sys.cfg

# Check if the OS & version is supported
if [ "$distro" = "CentOS" ] || [ "$distro" = "RedHatEnterpriseServer" ] || [ "$distro" = "OracleServer" ] || [ "$distro" = "CloudLinux" ]; then
  if [ "$ver" = "7" ] || [ "$ver" = "8" ] || [ "$ver" = "9" ]; then
    echo "Supported distro; continuing installation"
  else
    echo -e "${red}$DISTROVERSIONERR"
    exit 1
  fi
elif [ "$distro" = "Ubuntu" ]; then
  if [ "$ver" = "18" ] || [ "$ver" = "20" ] || [ "$ver" = "22" ]; then
    echo "Supported distro; continuing installation"
  else
    echo -e "${red}$DISTROVERSIONERR"
    exit 1
  fi
elif [ "$distro" = "Debian" ]; then
  if [ "$ver" = "10" ] || [ "$ver" = "11" ]; then
    echo "Supported distro; continuing installation"
  else
    echo -e "${red}$DISTROVERSIONERR"
    exit 1
  fi
else
    echo -e "${red}$DISTROVERSIONERR${nocolor}"
  exit 1
fi

# Setting the RAM Disk size
IFNUMBER () {
read -e -i $RECSIZE -p "How big of a RAM Disk would you like? Please, enter an integer or just hit 'Enter' to accept the default size ->  " THESIZE
}

###################################################################################################################################################
echo -e "${red}======================================== IMPORTANT! ========================================${nocolor}"
echo -e "${green}This script automates the process of setting up a RAM Disk in Nagios XI.
DO NOT USE IT IF YOU HAD A RAMDISK, PREVIOUSLY INSTALLED ON YOUR SYSTEM
OR IF YOU ARE UNSURE IF YOU HAD ONE IN THE PAST!${nocolor}"
echo -e "${red}============================================================================================${nocolor}
"
read -p "Do you want to continue with automatic install? [Y/n] " AUTO
        case "$AUTO" in
                "[yY][eE][sS]" | "y" | "Y" | "")
                        echo "Proceeding with setting up RAM Disk in Nagios XI..."
                        ;;
                *)
                        echo "Installation canceled!"
            echo "To install RAM Disk manually, please follow this document:"
            echo -e "${cyan}http://assets.nagios.com/downloads/nagiosxi/docs/Utilizing_A_RAM_Disk_In_NagiosXI.pdf${nocolor}"
                        exit 0
        esac

# Checking if we have sufficient privileges
USERID "$NOTROOTERR"

# Making sure there are not config errors before we get started
echo "Checking for config errors..."
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
CHKEXITSTAT "$CONFIGERR"

# Backup configs prior to the RAM Disk install (just in case)
BACKUP

# Determining the recommended size of the RAM Disk based on the total number of hosts + services
# < 1000    --->    RAM Disk size = 100MB
# 1000-5000    --->    RAM Disk size = 300MB
# > 5000    --->    RAM Disk size = 500MB
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
echo ""
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

# Create mount point
mkdir -p -m 775 ${RAMDISKDIR}

# Add ramdisk
touch $SYSTEMD/ramdisk.service
echo "[Unit]
Description=Ramdisk
Requires=local-fs.target
After=local-fs.target
Before=nagios.service
[Service]
Type=simple
RemainAfterExit=yes
Restart=always
ExecStartPre=$(which mkdir) -p -m 775 ${RAMDISKDIR} ${RAMDISKDIR}/tmp ${RAMDISKDIR}/spool ${RAMDISKDIR}/spool/checkresults ${RAMDISKDIR}/spool/xidpe ${RAMDISKDIR}/spool/perfdata
ExecStartPre=$(which mount) -t tmpfs -o size=${THESIZE}m tmpfs ${RAMDISKDIR}
ExecStartPre=$(which mkdir) -p -m 775 ${RAMDISKDIR} ${RAMDISKDIR}/tmp ${RAMDISKDIR}/spool ${RAMDISKDIR}/spool/checkresults ${RAMDISKDIR}/spool/xidpe ${RAMDISKDIR}/spool/perfdata
ExecStart=$(which chown) -R nagios:nagios ${RAMDISKDIR}
[Install]
WantedBy=multi-user.target" > $SYSTEMD/ramdisk.service

# Add SELinux support if SELinux is already enabled
echo "Adding SELinux support if SELinux is already enabled..."
if [[ `command -v selinuxenabled` ]] && [[ `semanage fcontext -l | grep nagios_content_t` ]]; then
    $(which semanage) fcontext -a -t nagios_content_t "/var/nagiosramdisk(/.*)?"
    sed -i 's/ExecStart=/ExecStartPre=/g' $SYSTEMD/ramdisk.service
    sed -i "/chown/a ExecStart=$(which chcon) -R -t nagios_content_t -l s0 /var/nagiosramdisk" $SYSTEMD/ramdisk.service	
fi

# Start ramdisk service
systemctl daemon-reload
systemctl enable ramdisk.service
systemctl restart ramdisk.service  

# Modifying configs.
echo "Modifying configs..."

# Modifying /usr/local/nagios/etc/nagios.cfg
sed -i '/service_perfdata_file=/c\service_perfdata_file=/var/nagiosramdisk/service-perfdata' $NAGIOSCFG
sed -i '/host_perfdata_file=/c\host_perfdata_file=/var/nagiosramdisk/host-perfdata' $NAGIOSCFG
sed -i '/check_result_path=/c\check_result_path=/var/nagiosramdisk/spool/checkresults' $NAGIOSCFG
sed -i '/object_cache_file=/c\object_cache_file=/var/nagiosramdisk/objects.cache' $NAGIOSCFG
sed -i '/status_file=/c\status_file=/var/nagiosramdisk/status.dat' $NAGIOSCFG
sed -i '/temp_path=/c\temp_path=/var/nagiosramdisk/tmp' $NAGIOSCFG

# Modifying /usr/local/nagiosmobile/include.inc.php on versions older than 5.7.x
MOBILE

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

# Running reconfigure_nagios.sh and restarting services
echo "Reconfiguring nagios..."
cd /usr/local/nagiosxi/scripts
./reconfigure_nagios.sh
sleep 3

# Restart apache
if [ "$distro" = "Ubuntu" ] || [ "$distro" = "Debian" ]; then
    systemctl restart apache2.service
else
    systemctl restart httpd.service
fi

# Restart php-fpm
if [ $dist = el8 ] || [ $dist = el9 ]; then
    systemctl restart php-fpm
fi

# Restart nagios
systemctl restart nagios.service

# Restart npcd
systemctl restart npcd.service

echo -e "
${green}All done!
Old configs were backed up in $BACKUPDIR
RAM Disk was installed in $RAMDISKDIR
The RAM Disk size was set to $THESIZE MB${nocolor}
"
