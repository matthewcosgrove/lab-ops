
## Pre-requisite checks and set up with Ansible playbooks

Assuming you are on vcenter 7, the playbooks below should work. I'm aware that POST on resource pool was not supported on vcenter 6.5 and 6.7

### Step 1 - Check vCenter objects

```
# cd into this project
ansible-playbook prereq/vcenter_objects_check.yml
```

### Step 2 - Ensure vCenter objects get created

```
# cd into this project
ansible-playbook prereq/vcenter_objects_ensure_created.yml
```

### Alternative Step 2 with govc scripts

If for some reason you cannot use the playbook above, use this script instead

```
# cd into this project
./prereq/create_vcenter_objects_via_govc.sh
```
