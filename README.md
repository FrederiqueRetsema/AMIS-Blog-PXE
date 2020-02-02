# AMIS-Blog-PXE
Code for creating a PXE server on CentOS 8 (and example configuration files). I'm preparing a blog on the AMIS website https://technology.amis.nl/ that will describe how to create a PXE server in CentOS8 by hand. There is a lot to configure, so many things can go wrong. This github repository might help you to figure out what is going on in your environment. You can also use the setup script to create the environment for you. 

When something doesn't work, please check the following remarks:
- Did you change the IP-address 192.168.2.76 and the network 192.168.2 in the configuration of the DHCP configuration file to addresses in your own network? 
- Did you change the IP-address 192.168.2.76 in the configuration file /var/ftp/centos8.cfg? 
- Did you add an extra network card in the Hyper-V node TestPxe?
- Is there text in /var/log/vsftpd.log?
- The command journalctl -xe might also give more information

