## Overview

An opinionated way to roll out [BUCC](https://github.com/starkandwayne/bucc) on vsphere and beef up how it runs.

We use BUCC to get a seamlessly integrated BOSH, UAA, Concourse and CredHub. The integration between those component is also thoroughly [tested](https://pipes.starkandwayne.com/teams/bucc/pipelines/bucc) upstream by BUCC so we dont have to worry about versioning and compatibility issues.

By default, BUCC runs with all jobs (i.e. processes) co-located on one VM created by the command [create-env](https://bosh.io/docs/init-vsphere/). This project extends BUCC and puts the default Concourse worker VM on its own VM as this is what we are going to put to work the most and we want the ability to scale out, recreate the VM to fix problems etc via the bosh CLI. A similar approach can be applied to the other bosh jobs by following the same pattern if required. e.g. if you are worried about downtime on Concourse Web during BUCC upgrades.

The project also supports the following integrated components managed by the BUCC bosh director.
* minio (integrated to provide creds to Concourse pipelines so they can access an S3 bucket out of the box)
* prometheus (integrated to monitor Concourse)

Some opinions that affect if this project will work out of the box for you include (some of these can be modified fairly easily but there is no documentation around this)
* You use resource pools
* You will only run one BUCC on your Tools VM (i.e. where you will clone this repo to and run all the commands)
* The bosh cli alias and the fly cli alias are both `bucc`
* You treat the environment as ephemeral. See "State Caveat" section below.

### State Caveat

The state repo for BOSH described in detail further below is your responsibility to manage and a deep understanding of BOSH is recommended for Day 2 Ops maintenance. Failing that, to avoid digging into the weeds when a need for troubleshooting arises, one option is to just blow away the state directory and start again. You may still have some clean up to do manually though... which is where your vcenter skills become important. 

Just make sure you have scripted up any population of CredHub (see [bin/credhub_populate_vcenter.sh](bin/credhub_populate_vcenter.sh) for an example of this) and have everything else in git. There are various things you can do in addition to this. You could run back ups on the CredHub via export/import and your Concourse config/history could be saved by running Postgres back ups ([bucc does support BBR for back ups](https://github.com/starkandwayne/bucc#backup--restore)).

## Prereqs

NOTE: Use the Ansible playbooks as described in [prereqs/README.md](prereqs/README.md) to check and set up your vcenter objects as required.

* You need to use a vcenter admin account or check your user has the permissions outlined in the docs [here](https://github.com/cloudfoundry/bosh-vsphere-cpi-release/blob/master/docs/required_vcenter_privileges.md).
* `GOVC_` env vars chosen for your installation. i.e. you have determined your choice of cluster, resource pool, vm folder etc. See [env_bucc_template](env_bucc_template) which will be used in the set up steps below.
* The DRS config needs to be set to "Partially Automated" or "Fully Automated". If set to "Manual" bosh VM creation will fail. Go to the vcenter UI, click on your cluster, go to the Configure tab, and under Services > vSphere DRS to check. The [prereq Ansible playbook](prereqs/vcenter_objects_check.yml) mentioned above will check this and fail if not set up as required.
* Deploy the [Tools VM](https://github.com/matthewcosgrove/deploy-tools-vm) that has been specifically configured to work with this solution.

The tools VM above automates the clone of this repo, but if you are going solo with your own approach then you will need to remember to include the submodules

```
git clone --recurse-submodules git@github.com:matthewcosgrove/lab-ops.git
# or with https
git clone --recurse-submodules https://github.com/matthewcosgrove/lab-ops.git
```

and also ensure your local system has the correct [bosh dependencies](https://bosh.io/docs/cli-v2-install/#additional-dependencies)

After that you are on your own as the rest of this README assumes you are using the associated [Tools VM](https://github.com/matthewcosgrove/deploy-tools-vm).

## Your Settings and State

This project is essentially a wrapper around [BUCC](https://github.com/starkandwayne/bucc). Just running bucc by itself creates a state dir within the bucc repo. We override the state location with the env var `BBL_STATE_DIR` which is what bucc uses. See the implementation [here](https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L8). We use another git repo outside of this one to manage your state and the specific configuration of the BUCC instance you are going to manage.

Next we need a way to tell our scripts and bucc where your state repo is..

In your `~/.profile` the Tools VM automation has already put the lines
```
export BUCC_WRAPPER_ROOT_DIR="/home/ubuntu/lab-ops"
state_repo_root_dir="/home/ubuntu/lab-ops-state"
export BBL_STATE_DIR="${state_repo_root_dir}/state" # BBL_STATE_DIR is the convention use by BUCC https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L8  
```

IMPORTANT: Check the Tools VM automation created a `.gitignore` file at the root of your new state repo with the entry `director-vars-*.yml`. Without this you may accidently commit sensitive data to git.

IMPORTANT: The `/home/ubuntu/lab-ops-state/state` dir is ephemeral and is wiped out on teardown. Do NOT put your own bosh operator files in there unless they are copies!!

At the root of that repo there needs to be a file called `env_bucc` which we will generate in the next section. Anything you want to keep can be in the root of the repo just like the `env_bucc` which will not be wiped out in between deployments. i.e.

`/home/ubuntu/lab-ops-state` ---> safe
`/home/ubuntu/lab-ops-state/state` ---> NOT safe

## Preparation Steps

1) Set up the required environment variables.

  a) Create the file `mkdir -p /home/ubuntu/lab-ops-state; cp /home/ubuntu/lab-ops/env_bucc_template /home/ubuntu/lab-ops-state/env_bucc`

  b) Populate the env vars `vim /home/ubuntu/lab-ops-state/env_bucc`. Do NOT put your govc credentials in here as we will version control this file.

  c) Source the env vars `source /home/ubuntu/lab-ops-state/env_bucc`

  d) In your current shell `export GOVC_USERNAME='changeme' GOVC_PASSWORD='changeme'`

2) Check the vcenter creds are configured as expected for govc by running `govc about; govc ls`. 

## Rollout BUCC

Either

1) Deploy just bucc with and external Concourse worker VM

```
/home/ubuntu/lab-ops/bin/deploy_bucc.sh
```

2) OR, to deploy bucc plus Minio

```
/home/ubuntu/lab-ops/bin/deploy_full_stack.sh
```

Once the deployment is complete commit and push your state repo!

## Day2Ops BUCC

To interact with BUCC going forwards and have all the CLIs configured to work out the box

1) PREP ENV VARS

```
init-govc
# Nothing else to do here as BUCC env vars are sourced on login to the Tools VM
```

2) PREP CLIs for automated logins
```
govc ls
bucc test
bucc info
bucc fly
fly -t bucc pipelines
bucc bosh
bosh vms
bucc credhub
credhub find
# etc
```
see [BUCC README docs](https://github.com/starkandwayne/bucc/blob/master/README.md) for more out of the box capabilities

3) Look after your BUCC

You should learn the bucc cli and note that all the bucc commands that rely on state have to be run through the bucc wrapper script. This project has symlinked the `bucc` command to force it to go through the [bin/bucc_wrapper.sh](bin/bucc_wrapper.sh) so that aspect is taken care of for you.

## Advanced Configuration - Extending the solution

Assuming you understand [bosh](https://bosh.io/docs/) (if not see this [tutorial](https://ultimateguidetobosh.com/) and this [explanation](https://bosh.io/docs/problems/)), any customizations should be put in the `$BBL_STATE_DIR/state/operators` directory for BUCC to find and integrate via the normal [bosh operator file mechanism](https://bosh.io/docs/cli-ops-files/)

Want to integrate additional bosh releases? See this list sorted by updated date https://github.com/search?o=desc&p=2&q=bosh+release&s=updated&type=Repositories

To extend the `cloud-config.yml` copy the [infra/cloud-config.yml](infra/cloud-config.yml) into your lab-ops-state root directory and start editing according to your needs. This override will occur in [bin/bosh_update_cloud_config.sh](bin/bosh_update_cloud_config.sh). Additional vars should then be placed in the yaml `bucc-extra-vars.yml` within the root of the lab-ops-state dir
