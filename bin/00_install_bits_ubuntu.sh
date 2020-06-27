#!/bin/bash

set -euo pipefail
required_packages=(spruce jq govc)
all_installed="true"

set +e
for package in "${required_packages[@]}";do
  dpkg -s "$package" &> /dev/null
  if [ $? -eq 0 ]; then
    echo "$package is installed!"
  else
    echo "$package is NOT installed!"
    all_installed="false"
  fi
done
set -e

echo "All required packages installed: $all_installed"
if [[ "$all_installed" == "false" ]];then
  echo "Installing required packages"
  sudo apt-get update
  sudo apt-get install wget -y
  wget -q -O - https://raw.githubusercontent.com/starkandwayne/homebrew-cf/master/public.key | sudo apt-key add -
  echo "deb http://apt.starkandwayne.com stable main" | sudo tee /etc/apt/sources.list.d/starkandwayne.list
  sudo apt-get update
  sudo apt-get install spruce -y
  sudo apt-get install jq -y
  sudo apt-get install govc -y
fi
