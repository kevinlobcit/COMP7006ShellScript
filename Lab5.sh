# A simple shell script to install and configure
# Apache/NFS/SAMBA

########################################################################
# Apache Body
########################################################################
apache()
{
  while true
    do
    	clear
    	cat << 'APACHE_MENU'
	Apache Menu
    1..................................Install Apache
    2..................................Add new user
    Q..................................Quit
APACHE_MENU

	echo -n '           Press letter for choice, then Return >'
	read ltr rest
	case ${ltr} in
		[1])	apacheinstall ;;
		[2])	apache_adduser ;;
		[Qq])	break;;

		*)	echo; echo Unrecognized choice: ${ltr};;
	esac
	echo; echo -n ' Press Enter to continue.....'
	read rest
	done
}

apacheinstall()
{
	dnf install httpd -y

	sed -i 's/UserDir disabled/#UserDir disabled/g' /etc/httpd/conf.d/userdir.conf
	sed -i 's/#UserDir public_html/UserDir public_html/g' /etc/httpd/conf.d/userdir.conf

	mkdir /var/www/html/passwords
	chmod 755 -R /var/www/html/passwords

  #remove the any access from any wepage
  apache_forcewebsitelogin

  #protect the passwords
  cat << EOF >> /etc/httpd/conf.d/userdir.conf
<Directory /var/www/html/passwords>
	order deny,allow
	deny from allow
</Directory>
EOF

  systemctl restart httpd
  systemctl enable httpd
}

apache_adduser()
{
  echo -n 'Enter username: '
  read username rest
  echo -n 'Enter password: '
  read password rest

  useradd -m $username
  echo "$username:$password" | chpasswd
  echo "User=$username created with password=$password"
  
  echo "Creating basic user html webpage"
  apache_createuserhtml $username
  chmod -R 775 /home/$username
  echo 'Added' $username 'webpage successfully.'

  apache_adduserpasswd $username $password
  echo "Added $username website password $password successfully"

  #restart httpd after changes to userdir.conf
  systemctl restart httpd
}

apache_createuserhtml()
{
  #echo $1
  mkdir /home/$1/public_html
  cat << EOF > /home/$1/public_html/index.html
<html>
<head>
	<title>$1's userpage</title>
</head>
<body>
	The owner of this page is $1
</body>
</html>
EOF
}

apache_adduserpasswd()
{
  # create password file with $1 filename of 
  # $1 username and $2 password
  htpasswd -c -b /var/www/html/passwords/$1 $1 $2

  #add entry for user to userdir.conf
  echo 'Adding user to the directory'
  cat >> /etc/httpd/conf.d/userdir.conf <<EOL
  <Directory /home/$1>
    AllowOverride None
    AuthUserFile /var/www/html/passwords/$1
    # Group authentication is disabled
    AuthGroupFile /dev/null
    AuthName test
    AuthType Basic
    <Limit GET>
      require valid-user
      order deny,allow
      deny from all
      allow from all
    </Limit>
  </Directory>
EOL

}

apache_forcewebsitelogin()
{
  #need to target entire block to delete
  # <Directory \"/home/*/public_html\">
  # AllowOverride FileInfo AuthConfig Limit Indexes
  # Options MultiViews Indexes SymLinksIfOwnerMatch IncludesNoExec
  # Require method GET POST OPTIONS
  # </Directory>

  #create temp file to write new userdir without the last 5 lines
  touch /etc/httpd/conf.d/tempuserdir.conf
  
  #write userdir withoout the last 6 lines to tempuserdir.conf
  head -n -6 /etc/httpd/conf.d/userdir.conf > /etc/httpd/conf.d/tempuserdir.conf
  
  #copy back the contents of tempuserdir.conf to the original userdir.conf
  cat /etc/httpd/conf.d/tempuserdir.conf > /etc/httpd/conf.d/userdir.conf
  
  #delete the tempuserdir.conf
  rm /etc/httpd/conf.d/tempuserdir.conf
}

########################################################################
# NFS Body
########################################################################
nfs()
{
  while true
    do
    	clear
    	cat << 'NFS_MENU'
    NFS Menu
    1..................................Install NFS
    2..................................Add directory to share
    Q..................................Quit
NFS_MENU

	echo -n '           Press letter for choice, then Return >'
	read ltr rest
	case ${ltr} in
		[1])	nfsinstall ;;
		[2])	nfsaddshare ;;
		[Qq])	break;;

		*)	echo; echo Unrecognized choice: ${ltr};;
	esac
	echo; echo -n ' Press Enter to continue.....'
	read rest
	done
}

nfsinstall()
{
  dnf install nfs-utils -y
  systemctl start nfs-server
  systemctl enable nfs-server
  mkdir /temp
  chmod -R 777 /temp
}

nfsaddshare()
{
  echo -n "Enter IP to share to: "
  read ipaddress rest
  echo -n "Enter subnet mask: "
  read subnet rest

  #add the entry to /etc/exports file
  echo "/temp $ipaddress/$subnet(rw,no_root_squash)" >> /etc/exports
  systemctl restart nfs-server
  exportfs -v
}

########################################################################
# Samba Body
########################################################################
samba()
{
	while true
    do
    	clear
    	cat << 'SAMBA_MENU'
    SAMBA Menu
    1..................................Install Samba
    2..................................Add new Samba user
    Q..................................Quit
SAMBA_MENU

	echo -n '           Press letter for choice, then Return >'
	read ltr rest
	case ${ltr} in
		[1])	sambainstall ;;
		[2])	sambanew_user ;;
		[Qq])	break;;

		*)	echo; echo Unrecognized choice: ${ltr};;
	esac
	echo; echo -n ' Press Enter to continue.....'
	read rest
	done
}

sambainstall()
{
  dnf install samba -y
  systemctl restart smb.service
  systemctl enable smb.service
}

sambanew_user()
{
  echo -n "Enter username: "
  read username rest
  echo -n "Enter password: "
  read password rest

  useradd -m $username
  echo "$username:$password" | chpasswd

  cat >> /etc/samba/smb.conf <<EOF
[$username]
    comment = $username's SAMBA
    path = /home/$username
    public = yes
    writable = yes
    printable = no
    valid users = $username
    force user = $username
EOF

  (echo $password; echo $password) | smbpasswd -a -s $username
  chmod -R 777 /home/$username
}

########################################################################
# Main Body
########################################################################
while true
do
	clear
	cat << 'MENU'
	Main Menu
	1..................................Apache
	2..................................NFS
	3..................................SAMBA
	Q..................................Quit
MENU

	echo -n '           Press letter for choice, then Return >'
	read ltr rest
	case ${ltr} in
		[1])	apache ;;
		[2])	nfs ;;
		[3])	samba ;;
		[Qq])	exit	;;

		*)	echo; echo Unrecognized choice: ${ltr};;
	esac
	echo; echo -n ' Press Enter to continue.....'
	read rest
done
