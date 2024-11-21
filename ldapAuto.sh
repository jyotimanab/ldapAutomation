#!/bin/bash

# A simple menu script using case
while true; do

	echo "Select an option:"
	echo "1. Install openldap"
	echo "2. Generate ldap admin password and update in db.ldif"
	echo "3. Genarete Domain name and update"
	echo "4. configure ldap server"
	echo "5. check ldap server"
	echo "6. Exit"

	# Read user input
	read -p "Enter your choice (1-6): " choice

	case $choice in
    		1)
        		echo "Install openldap:"
			echo "current Directory is": `pwd`
       			sleep 5	
        		yum localinstall openldap* -y
			if [ $? -eq 0 ]; then
				echo " ldap package installed successfully"
				rpm -qa | grep openldap*
				systemctl start slapd.service
				systemctl enable slapd.service
				sleep 2
				echo "Increaseing MDB size to 5 GB"
				ldapmodify -Y EXTERNAL -H ldapi:/// -f set-maxsize.ldif
				sleep 2
				echo "Configuring LDAP Log files"
				ldapmodify -Y EXTERNAL -H ldapi:/// -f log.ldif
			else
				echo "Unable to install packages"
				exit 1
			fi	
        		;;
   		 2)
        		echo "Generate ldap password and update:"
			#read -sp "Enter admin password" user_password
			user_password="Admin@Welcome123"
			echo

			#Generate hashed password
			hashed_password=$(echo "$user_password" | slappasswd -s $user_password)
			#hashed_password= $(slappasswd -s $user_password)
			# check password
			if [ $? -eq 0 ]; then
				echo "Hashed password is $hashed_password"
			else
				echo "password not generated"
				exit 1
			fi

			ldif_file="db.ldif"
			#check file
			if [ ! -f  "$ldif_file" ]; then
				echo "File not found"
				exit 1
			fi

			#update ldif file
			sed -i "s|^olcRootPW:.*|olcRootPW: $hashed_password|" "$ldif_file"
			#verify update
			if grep -q "olcRootPW: $hashed_password" "$ldif_file"; then
				echo "password updated successfully"
			else
				echo " Failed to update password"
				exit 1
			fi	

        		;;
    		3)
			# Generate domain components
			echo "Generate Domain:"
			read -p "Enter your domain name (e.g., example.com): " domain_info	
			IFS='.' read -r -a dc_parts <<< "$domain_info"
			dc_string=$(printf ",dc=%s" "${dc_parts[@]}")
			dc_string=${dc_string:1}  # Remove the leading comma
			 ldif_file="db.ldif"
			 echo $domain_info
			 sed -i "s|^olcSuffix:.*|olcSuffix: $dc_string|" "$ldif_file"
			 sed -i "s|^olcRootDN:.*|olcRootDN: cn=Administrator,$dc_string|" "$ldif_file"
			 read -p "Enter OU name (e.g., terdev):" ou_name

			 #generating base.ldif
			 base_ldif="base.ldif"

# Generate domain components
#IFS='.' read -r -a dc_parts <<< "$domain"
#dc_string=$(printf ",dc=%s" "${dc_parts[@]}")
#dc_string=${dc_string:1}  # Remove the leading comma

			cat > "$base_ldif" <<EOL
dn: $dc_string
objectClass: top
objectClass: domain

dn: ou=$ou_name,$dc_string
objectClass: organizationalUnit
ou: $ou_name

dn: cn=Administrator,$dc_string
objectClass: organizationalRole
cn: Administrator
description: LDAP Manager
EOL
#generating monitor.ldif
monitor_ldif="monitor.ldif"
cat > "$monitor_ldif" <<EOL

dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external, cn=auth" read by dn.base="cn=Administrator,$dc_string" read by * none
EOL
        		;;
			
		4)
			echo " configure ldap"
			output=$(ldapadd -Y EXTERNAL -H ldapi:/// -f "db.ldif" 2>&1)
			if [ $? -eq 0 ]; then
				echo " Operation succesful"
				echo "Installing scheme"
				sleep 2
				echo "$output"
				db_file=/etc/openldap/slapd.d/cn=config/olcDatabase\=\{2\}mdb.ldif
				echo "$db_file"
				echo $hashed_password
				sleep 2
				sed -i "s|^olcRootPW:.*|olcRootPW: $hashed_password|" "$db_file"
				ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
				ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
				ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
				echo " installing monitor.ldif"
				ldapmodify -Y EXTERNAL -H ldapi:/// -f monitor.ldif
				echo "install domain"
				sleep 2
				echo "$user_password"
				echo "install base domin"
				echo $domain_info
				base=$(ldapadd -x -D "cn=Administrator,$dc_string" -w "$user_password" -f base.ldif 2>&1)
			else
				echo "failed"
			fi	
			echo "$base"
		#	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
		#	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
		#	ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
	#		ldapmodify -Y EXTERNAL -H ldapi:/// -f monitor.ldif
			;;	
		5)	
			echo "Check LDAP Server"
			ldapsearch -x -b $dc_string	
			;;	
    		6)
        		echo "Exiting. Goodbye!"
        		exit 0
        		;;
    		*)
        		echo "Invalid choice. Please select a valid option."
        		;;
	esac
	echo
done	

