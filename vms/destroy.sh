#!/bin/bash
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
WORKSPACE="flux-managed"
ENVIRONMENT_FILE="${SCRIPTDIR}/environments/${WORKSPACE}.yaml"

if [ ! -f "${ENVIRONMENT_FILE}" ]; then
  echo "Environment file not found at ${ENVIRONMENT_FILE}"
  exit 1
fi

cd "${SCRIPTDIR}"

curl --silent https://apaxy.vip.aceshome.com/ansible/vault-password -o ~/.vault-password
export ANSIBLE_CONFIG="${SCRIPTDIR}/ansible/ansible.cfg"

# playbooks to run, in order
PLAYBOOKS="destroy-k8s destroy-nodes"

for P in ${PLAYBOOKS[@]}; do

  # Ansible options
  ANSIBLE_OPTS="--extra-vars @${ENVIRONMENT_FILE}"
  # If we are not setting up the nodes, then add the inventory file to the command line
  if [ "${P}" != "setup-nodes" ]; then
    ANSIBLE_OPTS="-i inventory ${ANSIBLE_OPTS}"
  fi

  echo "****** Running ${P} ******"
  ansible-playbook ${ANSIBLE_OPTS} -vvv "ansible/${P}.yaml"
  if [ $? -ne 0 ]; then
    echo "error running ${P}"
    exit 1
  fi
  echo
  echo
done


