#!/bin/bash

scripts=(
    "go_install.sh"
    "commandline-tools_install.sh"
)

for script in "${scripts[@]}"; do
  echo "Running script: $script"
  bash "$script"
  status=$?
    
  if [ $status -ne 0 ]; then
    echo "Script $script failed with status $status. Exiting."
    exit $status
  fi
done

echo "All scripts executed successfully."