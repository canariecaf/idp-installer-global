#!/bin/bash
# UTF-8


HELP="
##############################################################################
  Federated Identity Deployer Tools by:                              
 
 Anders Lördal,  SWAMID                                                     
 Chris Phillips, CANARIE                                 

 Version 3.1.0                                                               
                                                                            
 Deploys a working IDP for SWAMID or CANARIE CAF on an Ubuntu, CentOS or Redhat system     
 SAML2 Uses:
      jetty-9.2.14
      shibboleth-identityprovider-3.2.1
      cas-client-3.3.3-release
      mysql-connector-java-5.1.35 (for EPTID)
      mysql DB 5.6 Community Release                     
eduroam uses:
      freeRADIUS-3.0.1
      samba-4.1.1 (to connect to AD for MS-CHAPv2)


SWAMID  specific questions contact: noc@sunet.se            
CANARIE specific questions contact: tickets@canarie.ca            

##############################################################################
"

# Copyright 2017 Chris Phillips CANARIE, Anders Anders Lördal SWAMID
#
# This software is free software Licensed under the 
#   Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


if [ "${USERNAME}" != "root" -a "${USER}" != "root" ]; then
	echo "Run as root!"
	exit
fi

Spath="$(cd "$(dirname "$0")" && pwd)"

# load boostrap functions needed early on in this process
. ${Spath}/files/script.messages.sh
. ${Spath}/files/script.bootstrap.functions.sh
setEcho
# (validateConfig)
guessLinuxDist
setDistCommands

${Echo} "\n\n\nStarting up.\n\n\n"
${Echo} "Live logging can be seen by this command in another window:\ntail -f ${statusFile}"
${Echo} "Sleeping for 4 sec and then beginning processing..."
${Echo} "==============================================================================="
sleep 4
# bootstrapping step from minimal install
#
# bindutils to get the basic host info from machine
# dos2unix to ensure we have a clean include of hand managed files
#

if [ ! -f "/usr/bin/host" -o ! -f "/usr/bin/dos2unix" ]; then
	${Echo} "\nAdding a few packages that we will use during the installation process..."
	${Echo} "Package updates on the machine which could take a few minutes."
	if [ "${dist}" = "ubuntu" ]; then

		apt-get update --fix-missing &> >(tee -a ${statusFile})
		# apt-get -y upgrade &> >(tee -a ${statusFile})
		apt-get -y install dos2unix ntpdate &> >(tee -a ${statusFile})
		service ntp status > /dev/null 2>&1
		ntpCheck=$?
		if [ ${ntpCheck} -eq 0 ]; then
			service ntp stop
		fi
	elif [ "${dist}" = "sles" ]; then
		zypper -n install -l bind-utils net-tools lsb-release ntp dos2unix &> >(tee -a ${statusFile})
	else
		yum -y install bind-utils net-tools ntpdate dos2unix &> >(tee -a ${statusFile})
	fi
fi

if [ "${dist}" = "ubuntu" ]; then
	service ntp status > /dev/null 2>&1
	ntpCheck=$?
	if [ ${ntpCheck} -eq 0 ]; then
		service ntp stop
	fi
elif [ "${dist}" = "sles" ]; then
	service ntpd status > /dev/null 2>&1
	ntpCheck=$?
	if [ ${ntpCheck} -eq 0 ]; then
		service ntpd stop
	fi
fi

# read config file as early as we can so we may use the variables
# use dos2unix on file first however in case it has some mad ^M in it

if [ -s "${Spath}/config" ]
then
	dos2unix ${Spath}/config
	. ${Spath}/config		# dynamically (or by hand) editted config file
	. ${Spath}/config_descriptions	# descriptive terms for each element - uses associative array cfgDesc[varname]

	ValidateConfig

	if [ -z "${installer_interactive}" ]
	then
		installer_interactive="y"
	fi

	if echo "${installer_section0_buildComponentList}" | grep -q "shibboleth"; then
		validateConnectivity ${installer_section0_version}

		checkEptidDb
	fi

else
	${Echo} "Sorry, this tool requires a configuration file to operate properly. \nPlease use ~/wwww/appconfig/<your_federation>/index.html to create one. Now exiting"
	exit

fi


. ${Spath}/files/script.functions.sh
. ${Spath}/files/script.eduroam.functions.sh


# import the federation override file. It must exist even if it is empty.
federationSpecificInstallerOverrides="${Spath}/files/${my_ctl_federation}/script.override.functions.sh"

if [ -f "${federationSpecificInstallerOverrides}" ]
then
	${Echo} "Adding federation specific overrides for the install process from ${federationSpecificInstallerOverrides}" >> ${statusFile} 2>&1
	. ${federationSpecificInstallerOverrides}
else
	${Echo} "\n\nNo federation specific overrides detected for federation: ${my_ctl_federation} (if this was blank, the config file does not contain BASH variable my_ctl_federation)"
	${Echo} "\n\nIf there was a value set, but no override file exists, then this installer may be incomplete for that federation. \nPlease refer to the developer docs in ~/docs, exiting now" 
	exit
fi








setBackTitle


# parse options
options=$(getopt -o ckh -l "help" -- "$@")
eval set -- "${options}"
while [ $# -gt 0 ]; do
	case "$1" in
		-c)
			GUIen="n"
		;;
		-k)
			cleanUp="0"
		;;
		-h | --help)
			${Echo} "${HELP}"
			exit
		;;
	esac
	shift
done

$Echo "" >> ${statusFile}

#################################
#################################

#setDistCommands
setHostnames




setInstallStatus


while [ "${mainMenuExitFlag}" -eq 0 ]; do

	displayMainMenu

done




#################################
#################################



cleanupFilesRoutine




notifyUserBeforeExit
showAndCleanupMessagesFile
