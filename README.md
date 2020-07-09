## Overview

An opinionated way to roll out [BUCC](https://github.com/starkandwayne/bucc) on vsphere and beef up how it runs.

We use BUCC to get a seamlessly integrated BOSH, UAA, Concourse and CredHub. The integration between those component is also thoroughly [tested](https://pipes.starkandwayne.com/teams/bucc/pipelines/bucc) upstream by BUCC so we dont have worry about versioning and compatibility issues.

By default, BUCC runs with all jobs (i.e. processes) co-located on one VM created by the command [create-env](https://bosh.io/docs/init-vsphere/). This project extends BUCC and puts the default Concourse worker VM on its own VM as this is what we are going to put to work the most and we want the ability to scale out, recreate the VM to fix problems etc via the bosh CLI. A similar approach can be applied to the other bosh jobs by following the same pattern if required. e.g. if you are worried about downtime on Concourse Web during BUCC upgrades.

The project also supports the following integrated components managed by the BUCC bosh director.
* minio (integrated to provide creds to Concourse pipelines so they can access an S3 bucket out of the box)
* prometheus (integrated to monitor Concourse)

Some opinions that affect if this project will work out of the box for you include (some of these can be modified fairly easily but there is no documentation around this)
* You use resource pools
* You will only run one BUCC on your Tools VM (i.e. where you will clone this repo to and run all the commands)
* The bosh cli alias and the fly cli alias are both `bucc`
* You treat the environment as ephemeral. The state repo for BOSH described below is your responsibility to manage and a deep understanding of BOSH is recommended for Day 2 Ops maintenance, which is possible but requires expertise. Failing that, to avoid digging into the weeds when a need for troubleshooting arises, one option is to just blow away the state directory and start again. You may still have some clean up to do manually though... which is where your vcenter skills become important. Just make sure you have scripted up any population of CredHub (see [bin/credhub_populate_vcenter.sh](bin/credhub_populate_vcenter.sh) for an example of this) and have everything else in git. You can kiss goodbye to such things as your Concourse history though unless you fancy running Postgres back ups ([bucc does support BBR for back ups btw](https://github.com/starkandwayne/bucc#backup--restore)).

## Prereqs

Clone this repo, with the submodules

```
git clone --recurse-submodules git@github.com:matthewcosgrove/lab-ops.git
# or with https
git clone --recurse-submodules https://github.com/matthewcosgrove/lab-ops.git
```

Tested on Ubuntu 16.04 installed via OpsMan OVA 2.9. See an opinionated set up here: https://gist.github.com/matthewcosgrove/9e77386991d77873ca6700acda9225bc

IT IS RECOMMENDED TO RUN THROUGH THE SET UP OF THE GIST ON UBUNTU 16.04 DEPLOYED VIA OPSMAN OVA. MOST INSTRUCTIONS AND SCRIPTS ASSUME THAT THIS IS THE SET UP YOU HAVE SO YOU MIGHT HAVE TO TWEAK THEM IF YOU ARE DOING SOMETHING DIFFERENT

Instructions below will reference the gist above. Where relevant each instruction will say something like

```
WITH GIST: Do this semi-automated step

WITHOUT GIST: Do this manual step or steps
```

The gist set up above does not currently install the CLIs we need. 

* govc
* spruce
* jq

Instead that script is in this repo, so assuming Ubuntu run the following from the root of this repo

```
./bin/00_install_bits_ubuntu.sh
```

Prereqs that we don't do check through the scripts but could do

* Run pre-checks on the `GOVC_*` creds and config using govc commands. You need to use a vcenter admin account or check your user has the permissions outlined in the docs [here](https://github.com/cloudfoundry/bosh-vsphere-cpi-release/blob/master/docs/required_vcenter_privileges.md).
* Ensure the supported DRS mode is set on the cluster via govc. Instead you should go to the vcenter UI, click on your cluster, go to the Configure tab, and under Services > vSphere DRS check the config is set to "Partially Automated" or "Fully Automated". If set to "Manual" bosh VM creation will fail.

## Your Settings and State

This project is is essentially a wrapper around [BUCC](https://github.com/starkandwayne/bucc). Just running bucc by itself creates a state dir within the bucc repo. We override the state location with the env var `BBL_STATE_DIR` which is what bucc uses. See [here](https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L8)

So the first step is to create a repo outside of this one to manage your state and the specifics of the BUCC instance you are going to manage.

IMPORTANT: Immediately create a `.gitignore` file at the root of your new state repo with the entry `director-vars-*.yml`. Without this you may accidently commit sensitive data to git.

Next we need a way to tell our scripts and bucc where your state repo is..

In your `~/.profile` put the lines
```
export BUCC_WRAPPER_ROOT_DIR="CHANGE-ME" # e.g. "/home/ubuntu/lab-ops"
state_repo_name="CHANGE-ME" # e.g. "/home/ubuntu/lab-ops-state"
export BBL_STATE_DIR="~/${state_repo_name}/state" # BBL_STATE_DIR is the convention use by BUCC https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L8 

# IMPORTANT: Sourcing of .functions MUST come after the lines above. See gist for examples 
```
obviously changing `state_repo_name` to point to the repo you just created

You can create the state directory inside the new repo as well or just leave it to the scripts.

EXTREMELY IMPORTANT: The state dir is ephemeral and is wiped out on teardown. Do NOT put your own operator files in there unless they are copies!!

At the root of that repo there needs to be a file called `infra-settings.yml` which we will generate in the next section. Anything you want to keep can be in the root of the repo just like the `infra-settings.yml` which will not be wiped out in between deployments

## Preparation Steps

1) We generate the `infra-settings.yml` via env vars.
  
  a) Copy and populate your `~/.profile` as seen in [reference-env-vars.txt](reference-env-vars.txt)
  
  b) From the root of this repo run the following script

```
bin/generate_infra_settings.sh
```

2) Check the vcenter creds are available to govc. Follow instructions of output to set GOVC env vars manually if required which will be the case until the deploy script has been run further below.

WITH GIST: `init_govc`

WITHOUT GIST: cd to the root of this repo and `source ./bin/init_govc.sh`

## Rollout BUCC

To deploy

WITH GIST:
```
init_govc
bin/deploy_bucc.sh
```

WITHOUT GIST:
```
source bin/init_govc.sh
bin/deploy_bucc.sh
```

## Day2Ops BUCC

To interact with BUCC going forwards and have all the CLIs configured to work out the box

1) PREP ENV VARS

WITH GIST:
```
# Nothing to do here as env vars are sourced on login
```

WITHOUT GIST:
```
# Make sure your env vars are available in your shell by running the following command
source <(bin/env)
```

2) PREP CLIs for automated logins
```
bucc test
bucc info
bucc fly
fly -t bucc pipelines
bucc bosh
bosh vms
bucc credhub
credhub find
# etc (see BUCC docs for more out of the box capabilities)
```

3) Look after your BUCC

All the bucc commands that rely on state should be run through the bucc wrapper script. Other bucc commands can be run directly or via the wrapper script.

However, by convention, it is preferred to do everything through `bin\bucc_wrapper.sh`. For example, the [bin/deploy_bucc.sh](bin/deploy_bucc.sh) also calls bucc via the [bin/bucc_wrapper.sh](bin/bucc_wrapper.sh) script. In fact, what actually happens is we have a function for this which abstracts it all behind `bucc_cmd` so that, just like the scripts, you can take advantage of the same mechanism as follows

```
source bin/bucc_wrapper_helper.sh
bucc_cmd info
```

or for a bigger task like tearing everything down, which relies on access to the state...

```
# WARNING: This is the danger zone and this command will destroy your environment and bosh state
source bin/bucc_wrapper_helper.sh
bucc_cmd down
```
So instead of running "bucc down", by running the commands above you are doing it through the bucc_wrapper.sh script

## Advanced Configuration - Extending the solution

Assuming you understand [bosh](https://bosh.io/docs/) (if not see this [tutorial](https://ultimateguidetobosh.com/) and this [explanation](https://bosh.io/docs/problems/)), any customizations should be put in the `$BBL_STATE_DIR/state/operators` directory for BUCC to find and integrate via the normal [bosh operator file mechanism](https://bosh.io/docs/cli-ops-files/)
