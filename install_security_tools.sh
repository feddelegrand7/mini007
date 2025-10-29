#!/bin/bash

statuscode_tcdc_repo=$(curl -k -s -o /dev/null --write-out "%{http_code}" https://git.we.decodeinsurance.de/api/v4/projects/7081/packages)

# Check if script is being run by sudo user 
if [[ $EUID -ne 0 ]]; then
    echo "Exit code 1: This script must be run as sudo user" 1>&2
    exit 1
elif [[ ! $statuscode_tcdc_repo =~ "200" ]]; then
    echo "Exit code 2: Error accessing TCDC GitLab repository"
    read -n1 -r -p "Please check if your access to Barracuda VPN has been configured (please check the guide on the DevZone Hub https://devzone.hdi.cloud/devzone/devices/06_access_barracuda/). Thank you, press any key to exit  ...." key
    exit 2
fi

security_agents_installed=True

RED='\033[0;31m'
cd ~/Downloads

# Installing Microsoft Defender Agent 
install_defender () {
if [[ ! -d "/Applications/Microsoft Defender.app/" ]]; then
  security_agents_installed=False

  echo "${RED}Downloading and applying Microsoft Defender Configuration"
  curl -o "MicrosoftDefenderATPOnboardingMacOs.sh" "https://git.we.decodeinsurance.de/api/v4/projects/7081/packages/generic/Microsoft_Defender/latest/MicrosoftDefenderATPOnboardingMacOs.sh" --progress-bar

  echo "${RED}Downloading Microsoft Defender"
  curl -o wdav.pkg "https://git.we.decodeinsurance.de/api/v4/projects/7081/packages/generic/Microsoft_Defender/latest/wdav.pkg" --progress-bar
  open wdav.pkg
  read -n1 -r -p "Please install Microsoft Defender, than press any key to continue ...." key
  echo ""
  echo ""
  echo "Please Allow Full Disk Access in Preferences for Windows Defender and the Windows Defender Security Extension!"
  echo "Please Allow Network Content Filter in VPN & Filters for Windows Defender!"
  echo "Please Allow Notifications for Windows Defender!"
  echo ""
  echo ""
  read -n1 -r -p "Did you allow all Microsoft Defender settings?" key

  if [[ $? -ne 0 ]]; then
    defender_error="Exit code 3: Error occurred while trying to install the Defender Agent" 
    return 3
  fi
  sudo sh "MicrosoftDefenderATPOnboardingMacOs.sh"
  if [[ $? -ne 0 ]]; then
    defender_error="Exit code 4: Error occurred while trying to onboard the Defender Agent"
    return 4
  fi
  echo "Finishing Onboarding.....Please wait"
  sleep 30
  echo "Enabling Scans"
  sudo mdatp config scheduled-scan settings feature --value enabled
  sudo mdatp config scheduled-scan quick-scan time-of-day --value 700
  echo ""
  echo "Please reboot the system"
  echo ""
  if [[ "$(ps -ef | grep Defender)" =~ "Microsoft Defender" ]]; then
    return 0
  fi
fi
}
install_defender
install_defender_result=$?

# Installing Qualys Agent

install_qagent () {
if [[ ! -d "/Applications/QualysCloudAgent.app/" ]]; then
  security_agents_installed=False
  echo "${RED}Downloading Qualys Agent"

# Check Qualys Webservice
statuscode_qualys_webservice=$(curl -s -o /dev/null --write-out "%{http_code}" https://qagpublic.qg2.apps.qualys.eu)

if [[ ! $statuscode_qualys_webservice =~ "404" ]]; then
    qualys_error="Exit code 5: Error accessing Qualys Webservice"
    return 5
fi

  if [[ "$(uname -m)" =~ "x86_64" ]]; then
      echo "Intel x64 found"

      statuscode_qagent_dl=$(curl -k -s -o /dev/null --write-out "%{http_code}" https://git.we.decodeinsurance.de/api/v4/projects/7081/packages/generic/qualys_all/latest/qualys_macosx.pkg)
      
      if [[ $statuscode_qagent_dl =~ "200" ]]; then 
          curl -k https://git.we.decodeinsurance.de/api/v4/projects/7081/packages/generic/qualys_all/latest/qualys_macosx.pkg -o qualys_macosx.pkg --progress-bar
          sudo bash -c "sudo installer -pkg ./qualys_macosx.pkg  -target / && sudo /Applications/QualysCloudAgent.app/Contents/MacOS/qualys-cloud-agent.sh ActivationId=c966c178-2792-431e-9c24-f912cd79b6b4 CustomerId=6729cc83-e6b8-7b9f-8322-9a1ea7d0b8c6"
          if [[ $? -ne 0 ]]; then
            qualys_error="Exit code 6: Qualy Agent Installation aborted"
            return 6
          fi
      else
          qualys_error="Exit code 7: Error downloading Qualys Agent file"
          return 7
      fi
  fi

  if [[ "$(uname -m)" =~ "arm64" ]]; then
      echo "Apple ARM64 found"
  
      statuscode_qagent_dl=$(curl -k -s -o /dev/null --write-out "%{http_code}" https://git.we.decodeinsurance.de/api/v4/projects/7081/packages/generic/qualys_all/latest/qualys_macosx_m1.pkg)

      if [[ $statuscode_qagent_dl =~ "200" ]]; then 
          curl -k https://git.we.decodeinsurance.de/api/v4/projects/7081/packages/generic/qualys_all/latest/qualys_macosx_m1.pkg -o qualys_macosx_m1.pkg --progress-bar
          sudo bash -c "installer -pkg ./qualys_macosx_m1.pkg -target / && /Applications/QualysCloudAgent.app/Contents/MacOS/qualys-cloud-agent.sh ActivationId=c966c178-2792-431e-9c24-f912cd79b6b4 CustomerId=6729cc83-e6b8-7b9f-8322-9a1ea7d0b8c6"
          if [[ $? -ne 0 ]]; then
            qualys_error="Exit code 6: Qualys Agent Installation aborted"
            return 6
          fi
      else
          qualys_error="Exit code 7: Error downloading Qualys Agent file"
          return 7
      fi
  fi
  
  echo ""
  echo ""
  echo "Please Allow Full Disk Access in Preferences for Qualys!"
  echo "Please Allow Notifications for Qualys!"
  echo ""
  echo ""
  if [[ "$(ps -ef | grep qualys)" =~ "qualys-cloud-agent" ]]; then
      return 0
  else
      qagent_error="Exit code 8: Qualys Agent Service not properly installed"
      return 8
  fi

fi
}
install_qagent
install_qagent_result=$?

if $security_agents_installed; then
    read -n1 -r -p "Security agents are already installed. Thank you, press any key to exit  ...." key
    exit 0
elif [[ $install_qagent_result -eq 0 && $install_defender_result -eq 0 ]]; then
    read -n1 -r -p "Security agents have been installed successfully. Thank you, press any key to exit  ...." key
    exit 0
elif [[ $install_qagent_result -eq 0 && $install_defender_result -ne 0 ]]; then
    echo "Qualys Agent has been installed successfully, but an error occured while trying to install the Defender agent. Please refer to the exit code below for more details."
    echo $defender_error
    read -n1 -r -p "Please contact team TCDC (tcdc@hdi.de) for further troubleshooting. Thank you, press any key to exit  ...." key
    exit 9
elif [[ $install_qagent_result -ne 0 && $install_defender_result -eq 0 ]]; then
    echo "Defender Agent has been installed successfully, but an error occured while trying to install the Qualys agent. Please refer to the exit code below for more details."
    echo $qualys_error
    read -n1 -r -p "Please contact team TCDC (tcdc@hdi.de) for further troubleshooting. Thank you, press any key to exit  ...." key
    exit 9
else
    echo "The installation of the security agents failed. Please refer to the exit codes below for more details." 
    echo $qualys_error
    echo $defender_error
    read -n1 -r -p "Please contact team TCDC (tcdc@hdi.de) for further troubleshooting. Thank you, press any key to exit  ...." key
    exit 9
fi