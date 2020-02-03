# AMIS-Blog-PXE
Code for creating a PXE server on CentOS 8 (and example configuration files). This is the code that belongs to a blog on the AMIS website https://technology.amis.nl/ that will describe how to create a PXE server in CentOS8 by hand. There is a lot to configure, so many things can go wrong. This github repository might help you to figure out what is going on in your environment, both by giving you scripts for your own environment and by putting the resulting files on github. You can also use the setup script to create the environment for you. 

To use the scripts:
- Download CentOS8 ( https://www.centos.org/download )
- Change the parameters in the upper part of the powershell scripts
- Run the ps1 scripts in an elevated window (as administrator): these scripts will create a LinuxPxe and a TestPxe VM in Hyper-V
- Start LinuxPxe, see the AMIS blog for the settings
- Within LinuxPxe, get the scripts from git:
	yum install git -y
	git clone https://github.com/FrederiqueRetsema/AMIS-Blog-PXE
    cd AMIS-Blog-PXE
- Change the upper part of the script install-pxe for your (network-)settings, after that:
    . ./install-pxe.sh	

When something doesn't work, please check the following remarks:
- I put the configuration files of my (working) system in this github repository, you might check the differences with your system
- Did you change the names of directories and files in the upper part of the powershell scripts?
- Did you change the IP-address and the network settings in the installation script to addresses in your own network? 
- Did you change the name of the subnet in hex (C0A802) to match your network? (C0 = 192, A8 = 168, 02 = 2 -> this name belongs to network 192.168.2)
- Is there text in /var/log/vsftpd.log?
- The command journalctl -xe might also give more information
 
