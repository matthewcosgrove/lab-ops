
## Pre-requisite checks and set up with Ansible playbooks

Assuming you are on vcenter 7, the playbooks below should work. I'm aware that POST on resource pool was not supported on vcenter 6.5 and 6.7

Before running, install the required tools

```
# check your govc vars, these need to be there
env | grep GOVC_
# cd into this project
./prereqs/install_vmware_rest.sh
source prereqs/source_vmware_vars.sh
```

### Step 1 - Check vCenter objects

```
# cd into this project
ansible-playbook prereqs/vcenter_objects_check.yml
```

### Step 2 - Ensure vCenter objects get created

```
# cd into this project
ansible-playbook prereqs/vcenter_objects_ensure_created.yml
```

### Alternative Step 2 with govc scripts

If for some reason you cannot use the playbook above, use this script instead

```
# cd into this project
./prereqs/create_vcenter_objects_via_govc.sh
```
