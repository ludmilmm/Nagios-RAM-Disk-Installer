# Nagios-RAM-Disk-Installer
The install_ramdisk.sh script installs RAM disk on a Nagios XI server. It won't work with Nagios Core.

In order to install RAM disk on the Nagios XI server, run following commands from the command line:

```
cd /tmp
wget https://github.com/ludmilmm/Nagios-RAM-Disk-Installer/archive/master.zip
unzip master.zip
cd Nagios-RAM-Disk-Installer-master/
chmod +x install_ramdisk.sh
./install_ramdisk.sh
```
The automatic install is NOT supported on RHEL/CentOS 5. If you have an older distribution, you will need to follow the manual install instructions below. The same is valid in cases when you have a "non-standard" Nagios XI instance (custom paths, custom config locations, etc.) or you want to set up the RAM disk in a "non-default" location.

For more information, read the following document: 

https://assets.nagios.com/downloads/nagiosxi/docs/Utilizing_A_RAM_Disk_In_NagiosXI.pdf
