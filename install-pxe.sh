# Please look carefully to these settings, these will be used for configuration of the PXE server
#
PXESERVER_IP_ADDRESS=192.168.2.131
PXESERVER_DOMAIN_NAME="mydomain"
PXESERVER_SUBNET_MASK=255.255.255.0
PXESERVER_BROADCAST_ADDRESS=192.168.2.255
PXESERVER_DOMAIN_NAME_SERVERS=192.168.2.254
PXESERVER_ROUTERS=192.168.2.254
PXESERVER_SUBNET=192.168.2.0
PXESERVER_SUBNET_HEX=C0A802
PXESERVER_MIN_RANGE=192.168.2.200
PXESERVER_MAX_RANGE=192.168.2.210

DIR_TFTP=/var/lib/tftpboot
DIR_NETWORKBOOT=networkboot
DIR_TFTP_NETWORKBOOT=$DIR_TFTP/$DIR_NETWORKBOOT

DIR_FTP=/var/ftp
DIR_CENTOS8=CentOS8
DIR_FTP_CENTOS8=$DIR_FTP/$DIR_CENTOS8

DIR_PXE_PXELINUX_CFG=$DIR_TFTP/pxelinux.cfg

TEMPDIR=/tmp/install-pxe.`date +%Y%m%d-%H%M%S`
mkdir $TEMPDIR

CONFIGFILE_DHCP=/etc/dhcp/dhcpd.conf
CONFIGFILE_FTP=/etc/vsftpd/vsftpd.conf
CONFIGFILE_PXE=$DIR_PXE_PXELINUX_CFG/$PXESERVER_SUBNET_HEX

CONFIGFILE_KS_SHORT=centos8.cfg
CONFIGFILE_KS_ORG=~root/anaconda-ks.cfg
CONFIGFILE_KS=$DIR_FTP/$CONFIGFILE_KS_SHORT

CONFIGFILE_TFTPD_SERVICE=/etc/systemd/system/tftpd.service

# Functions
# ---------

check_ip_address() {
    IPCHECK=`ip address show | grep $PXESERVER_IP_ADDRESS`
    if (test -z "$IPCHECK") 
    then
        	echo "Check: result of IP-check: Other IP Address: this server doesn't have IP Address $PXESERVER_IP_ADDRESS"
        	echo "Advice: change the settings in this script before running it!"
            exit 1
    else 
        	echo "Check: - Result: IP Address matches one of the server IP addresses, continue"
    fi
}

check_existing_file() {
    TEMPDIR=$1
    FILE=$2

    if (test -f $FILE)
    then
        echo "Check: - File $FILE exists, will be copied to $TEMPDIR"
        cp $FILE $TEMPDIR
    else
        echo "Check: - File $FILE doesn't exist (yet)"
    fi
} 

check_dvd_present() {
    if (! test -f /mnt/.treeinfo)
    then
            echo "Check: - Result: CentOS disk not present in /mnt. Try to mount /dev/cdrom to /mnt..."
            mount /dev/cdrom /mnt
            if (test $? -eq 0)
            then
                echo "  - Mount succesful"
            else
                echo "Mount not succesful, exit"
                exit 1
            fi
    else
            echo "Check: - Result: CentOS disk present in /mnt"
    fi
}

check_file() {
    TAGNAME=$1
    FILENAME=$2
    if (! test -f $FILENAME) 
    then
        echo "- test NOT succeeded, $FILENAME not present, $TAGNAME is not running correctly..."
        exit 1
    else
        echo "- test succeeded, $FILENAME present, continue"
    fi
}

create_dir_if_necessary() {
    TAGNAME=$1
    DIRNAME=$2
    if (! test -d $DIRNAME)
    then
        echo "$TAGNAME: - No, create dir"
        mkdir $DIRNAME
    else
        echo "$TAGNAME: - Yes, directory already exists"
    fi
}

# MAIN program
# ------------

# Checks
#
# - IP Address: must be one of the IP addresses of this server
# - Configfile DHCP must not have any non-empty lines that doesn't start with # 

echo "Check: IP Address: must be one of the IP addresses of this server"
check_ip_address

echo "Check: DVD present in /mnt?"
check_dvd_present

# Check existing files, if they exist - make a backup
#

check_existing_file $TEMPDIR $CONFIGFILE_DHCP
check_existing_file $TEMPDIR $CONFIGFILE_FTP
check_existing_file $TEMPDIR $CONFIGFILE_PXE
check_existing_file $TEMPDIR $CONFIGFILE_KS
check_existing_file $TEMPDIR $CONFIGFILE_TFTPD_SERVICE

# Install updates and software
#

echo "Install updates and software..."

yum update -y

yum install epel-release -y
yum install dhcp-server ftp vsftpd syslinux tftp tftp-server -y

# DHCP
# 

echo "DHCP: change $CONFIGFILE_DHCP"

echo "allow booting;" > $CONFIGFILE_DHCP
echo "allow bootp;" >> $CONFIGFILE_DHCP
echo "" >> $CONFIGFILE_DHCP
echo "option domain-name \"$PXESERVER_DOMAIN_NAME\";" >> $CONFIGFILE_DHCP
echo "option subnet-mask $PXESERVER_SUBNET_MASK;" >> $CONFIGFILE_DHCP
echo "option broadcast-address $PXESERVER_BROADCAST_ADDRESS;" >> $CONFIGFILE_DHCP
echo "option domain-name-servers $PXESERVER_DOMAIN_NAME_SERVERS;" >> $CONFIGFILE_DHCP
echo "option routers $PXESERVER_ROUTERS;" >> $CONFIGFILE_DHCP
echo "" >> $CONFIGFILE_DHCP
echo "next-server $PXESERVER_IP_ADDRESS;" >> $CONFIGFILE_DHCP
echo "filename \"pxelinux.0\";" >> $CONFIGFILE_DHCP
echo "subnet $PXESERVER_SUBNET netmask $PXESERVER_SUBNET_MASK {" >> $CONFIGFILE_DHCP
echo "	range dynamic-bootp $PXESERVER_MIN_RANGE $PXESERVER_MAX_RANGE;" >> $CONFIGFILE_DHCP
echo "}" >> $CONFIGFILE_DHCP

# TFTP
# ----
# \ before cp is necessary to be sure an eventual alias isn't used

echo "TFTP: copy files"

\cp -f /usr/share/syslinux/pxelinux.0  $DIR_TFTP
\cp -f /usr/share/syslinux/memdisk     $DIR_TFTP
\cp -f /usr/share/syslinux/menu.c32    $DIR_TFTP
\cp -f /usr/share/syslinux/mboot.c32   $DIR_TFTP
\cp -f /usr/share/syslinux/chain.c32   $DIR_TFTP
\cp -f /usr/share/syslinux/ldlinux.c32 $DIR_TFTP
\cp -f /usr/share/syslinux/libutil.c32 $DIR_TFTP

echo "TFTP: $DIR_TFTP_NETWORKBOOT exists?" 

create_dir_if_necessary "TFTP" $DIR_TFTP_NETWORKBOOT

echo "TFTP: copy networkboot files" 

\cp /mnt/images/pxeboot/vmlinuz $DIR_TFTP_NETWORKBOOT
\cp /mnt/images/pxeboot/initrd.img $DIR_TFTP_NETWORKBOOT

# FTP
# 

echo "FTP: Change configfile"

sed -i.bkp '/^anonymous_enable=NO/c anonymous_enable=YES'  $CONFIGFILE_FTP
sed -i.bkp '/^local_enable=YES/c local_enable=NO'  $CONFIGFILE_FTP
sed -i.bkp '/^write_enable=YES/c write_enable=NO'  $CONFIGFILE_FTP

echo "FTP: Change log output of FTP (optional)"

# FTP: This is optional, comment the next lines out if you don't want to have excessive logfiles for ftp in /var/log/vsftpd.log
#

sed -i.bkp '/^xferlog_std_format=YES/c xferlog_std_format=NO'  $CONFIGFILE_FTP
PXELINENO=`grep -rne xferlog_std_format $CONFIGFILE_FTP | awk -F":" '{print $1}'`
sed -i.bkp "${PXELINENO}a log_ftp_protocol=YES" $CONFIGFILE_FTP

echo "FTP: $DIR_FTP_CENTOS8 already exists?"

create_dir_if_necessary "FTP" $DIR_FTP_CENTOS8

echo "FTP: Check if DVD is already copied..."
if (! test -f $DIR_FTP_CENTOS8/.treeinfo) 
then
    echo "FTP: - DVD not copied, copy DVD to local disk (this might take some time)"
    cp -a /mnt/* $DIR_FTP_CENTOS8
    cp -a /mnt/.treeinfo $DIR_FTP_CENTOS8
else
    echo "FTP: - DVD is already copied, continue..."
fi

# PXE
# 

echo "PXE: $DIR_PXE_PXELINUX_CFG already exists?"

create_dir_if_necessary "PXE" $DIR_PXE_PXELINUX_CFG

echo "PXE: create $CONFIGFILE_PXE"

echo "DEFAULT menu.c32" > $CONFIGFILE_PXE
echo "PROMPT 0" >> $CONFIGFILE_PXE
echo "TIMEOUT 30" >> $CONFIGFILE_PXE
echo "LABEL centos8s" >> $CONFIGFILE_PXE
echo "MENU CentOS 8 Server" >> $CONFIGFILE_PXE
echo "KERNEL /$DIR_NETWORKBOOT/vmlinuz" >> $CONFIGFILE_PXE
echo "APPEND initrd=/$DIR_NETWORKBOOT/initrd.img inst.repo=ftp://$PXESERVER_IP_ADDRESS/$DIR_CENTOS8 ks=ftp://$PXESERVER_IP_ADDRESS/$CONFIGFILE_KS_SHORT" >> $CONFIGFILE_PXE

# KS
#
 
echo "KS: copy original $CONFIGFILE_KS_ORG file to $CONFIGFILE_KS and change permissions"
\cp -f $CONFIGFILE_KS_ORG $CONFIGFILE_KS
chmod 644 $CONFIGFILE_KS

echo "KS: Make changes to $CONFIGFILE_KS"

PXELINENO=`grep -rne "repo --name=\"AppStream\"" $CONFIGFILE_KS | awk -F":" '{print $1}'`
sed -i.bkp "${PXELINENO}d" $CONFIGFILE_KS
sed -i.bkp "${PXELINENO}i repo --name=centos-updates --mirrorlist=http://mirrorlist.centos.org/?release=\$releasever\&arch=\$basearch\&repo=BaseOS --cost=1000" $CONFIGFILE_KS
sed -i.bkp "${PXELINENO}a repo --name=appstream-updates --mirrorlist=http://mirrorlist.centos.org/?release=\$releasever\&arch=\$basearch\&repo=AppStream --cost=1000" $CONFIGFILE_KS
let PXELINENO=PXELINENO+1
sed -i.bkp "${PXELINENO}a repo --name=extras-updates --mirrorlist=http://mirrorlist.centos.org/?release=\$releasever\&arch=\$basearch\&repo=Extras --cost=1000" $CONFIGFILE_KS

sed -i.bkp "/# Use CDROM installation media/c # Use FTP installation media" $CONFIGFILE_KS
sed -i.bkp "/cdrom/c url --url=ftp://$PXESERVER_IP_ADDRESS/$DIR_CENTOS8" $CONFIGFILE_KS

sed -i.bkp "/clearpart --/c clearpart --all" $CONFIGFILE_KS
PXELINENO=`grep -rne "clearpart --" $CONFIGFILE_KS | awk -F":" '{print $1}'`
sed -i.bkp "${PXELINENO}a zerombr" $CONFIGFILE_KS

sed -i.bkp "/network  --bootproto=dhcp --device=eth0 --onboot=off --ipv6=auto --activate/cnetwork  --bootproto=dhcp --device=eth0 --ipv6=auto --activate" $CONFIGFILE_KS

# Firewall
#

echo "Firewall: check if changing firewallsettings is necessary..."
FWCHECK=`firewall-cmd --list-service | grep proxy-dhcp`
if (test -z "$FWCHECK") 
then
    echo "- change settings is necessary"

    firewall-cmd --add-service=tftp --permanent
    firewall-cmd --add-service=ftp --permanent
    setsebool -P allow_ftpd_full_access 1

    firewall-cmd --add-service=proxy-dhcp --permanent

    firewall-cmd --reload
else
    echo "- change firewall settings is not necessary, continue"
fi

# Services
#

echo "Services: create tftpd servicefile $CONFIGFILE_TFTPD_SERVICE"

echo "[Unit]" > $CONFIGFILE_TFTPD_SERVICE
echo "Description=TFTP Service" >> $CONFIGFILE_TFTPD_SERVICE
echo "Documentation=man:in.tftpd" >> $CONFIGFILE_TFTPD_SERVICE
echo "" >> $CONFIGFILE_TFTPD_SERVICE
echo "[Service]" >> $CONFIGFILE_TFTPD_SERVICE
echo "ExecStart=/usr/sbin/in.tftpd -s -vvv -l -a :69 -r blksize -P /var/run/tftpd.pid $DIR_TFTP" >> $CONFIGFILE_TFTPD_SERVICE
echo "ExecStop=/bin/kill -15 $MAINPID" >> $CONFIGFILE_TFTPD_SERVICE
echo "PIDFile=/var/run/tftpd.pid" >> $CONFIGFILE_TFTPD_SERVICE
echo "" >> $CONFIGFILE_TFTPD_SERVICE
echo "[Install]" >> $CONFIGFILE_TFTPD_SERVICE
echo "WantedBy=multi-user.target" >> $CONFIGFILE_TFTPD_SERVICE

echo "Services: (re)start + enable services"

systemctl daemon-reload
systemctl restart dhcpd
systemctl enable dhcpd
systemctl restart tftpd
systemctl enable tftpd
systemctl restart vsftpd
systemctl enable vsftpd

echo "Services: wait a while before test..."
sleep 5

# Testing...
# 
echo "Testing: tftp"

cd ~root
rm -f menu.c32

# The reason for filtering out the error messages, is that sometimes tftp will timeout. The file is, however, present.
# Because that's the only thing that counts, the errors (if any) are ignored. 

tftp localhost 2> /dev/null <<here
get menu.c32
quit
here

check_file TFTP ~root/menu.c32

echo "Testing: ftp"

rm -f $CONFIGFILE_KS_SHORT
rm -f TRANS.TBL

ftp -n <<here  > /tmp/ftp_output.$$ 2> /dev/null
open localhost
user ftp ftp
get $CONFIGFILE_KS_SHORT
cd $DIR_CENTOS8
get TRANS.TBL
quit
here

# The reason for filtering out the warnings from the output, is that they are a result of not giving a cr + lf after each line within
# the ftp. This is normal for a Linux system. The warnings can safely be ignored, the only thing that matters is that the two files
# that we asked for should be present.
# 
cat /tmp/ftp_output.$$ | grep -v WARNING | grep -v "File may not have transferred correctly"

check_file FTP ~root/$CONFIGFILE_KS_SHORT
check_file FTP ~root/TRANS.TBL

echo ""
echo "End of installation, you might test the installation by using the TestPxe VM!"

