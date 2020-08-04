#!/bin/bash

repo_root_dir="$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )")"
export REPO_ROOT_DIR="${repo_root_dir}"

# BUCC conventions
export STATE_ROOT_DIR="${BBL_STATE_DIR}"/.. # Slight variance in naming style from https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L10
export STATE_VARS_DIR="${BBL_STATE_DIR}"/vars
export STATE_VARS_STORE="${STATE_VARS_DIR}"/director-vars-store.yml
export STATE_VARS_FILE="${STATE_VARS_DIR}"/director-vars-file.yml
export BOSH_STATE_JSON="${STATE_VARS_DIR}"/bosh-state.json
export STATE_OPS_FILES_DIR="${BBL_STATE_DIR}"/operators # as expected by BUCC https://github.com/starkandwayne/bucc/blob/2af7a2b47a151007b4db089f2349aa58bce8d1fc/bin/bucc#L147

# BUCC wrapper aka lab-ops conventions
export BOSH_MANIFEST_DIR="${REPO_ROOT_DIR}"/infra
export BOSH_OPS_FILES_DIR="${BOSH_MANIFEST_DIR}"/ops
export STATE_OPS_FILE_PREFIX="z-bucc-wrapper-"
export STATE_BUCC_CURRENT_YAML="${STATE_VARS_DIR}"/director-vars-bucc-current.yml # Follow convention to prevent commit (i.e.) .gitignore should contain entry director-vars-*
export BUCC_SUBMODULE_LOCATION="${REPO_ROOT_DIR}"/src/bucc
export BUCC_INFRA_SETTINGS_FILE="${STATE_ROOT_DIR}"/infra-settings.yml
bosh_env_alias=$(bosh int "${BUCC_INFRA_SETTINGS_FILE}" --path /alias)
export BOSH_ENV_ALIAS="${bosh_env_alias}"

function bucc_cmd() {
  "${REPO_ROOT_DIR}"/bin/bucc_wrapper.sh "$@"
}

function bosh_login() {
  echo "Using bosh CLI managed by BUCC.."
  if ! bucc_cmd bosh > /dev/null; then
    err_fatal "Cannot login into bosh via BUCC"
  fi
  bosh -v | grep version
}

function bosh_cmd() {
  bosh_login
  set -x
  bosh -e "$BOSH_ENV_ALIAS" -n "$@"
  set +x
}

function credhub_login() {
  echo "Using credhub CLI managed by BUCC.."
  if ! bucc_cmd credhub > /dev/null; then
    err_fatal "Cannot login into credhub via BUCC"
  fi
  credhub --version
  echo "Testing connection via get.."
  credhub get -n /concourse/main/bosh_name
}

function credhub_cmd() {
  credhub_login
  set -x
  credhub "$@"
  set +x
}

function mc_cmd() {
  MINIO_ACCESS_KEY=$(credhub get -n /concourse/main/minio_access_key -q)
  MINIO_SECRET_KEY=$(credhub get -n /concourse/main/minio_secret_key -q)
  MINIO_HOST=$(credhub get -n /concourse/main/minio_ip -q)
  export MC_HOST_bucc=http://${MINIO_ACCESS_KEY}:${MINIO_SECRET_KEY}@${MINIO_HOST}:9001
  set -x
  mc "$@"
  set +x
}

function upload_stemcell() {
  stemcell_url=$(bucc int --path /resource_pools/name=vms/stemcell/url)
  echo "Uploading stemcell $stemcell_url"
  stemcell_sha1=$(bucc int --path /resource_pools/name=vms/stemcell/sha1)
  bosh_cmd upload-stemcell --sha1="${stemcell_sha1}" "${stemcell_url}"
}

#######################################
# Update Cloud Config with pre-configured bosh cli.
# Arguments:
#   Path to cloud-config.yml file.
#   Optional array of flags.
# Returns:
#   0 if updated, non-zero on error.
#######################################
function bosh_update_cloud_config() {
  local manifest_yaml_file="$1"
  shift
  validate_bosh_interpolation "$manifest_yaml_file" "$@"
  bosh_cmd update-cloud-config "$manifest_yaml_file" "$@"
}

#######################################
# Deploy with pre-configured bosh cli.
# Arguments:
#   Path to Deployment manifest yaml file.
#   Deployment name.
#   Optional array of flags.
# Returns:
#   0 if deployed, non-zero on error.
#######################################
function bosh_deploy() {
  local manifest_yaml_file="$1"
  local deployment_name="$2"
  shift
  shift
  validate_bosh_interpolation "$manifest_yaml_file" "$@"
  upload_stemcell
  bosh_cmd -d "$deployment_name" deploy "$manifest_yaml_file" "$@"
}

#######################################
# Validates that the manifest will be interpolated as we expected so that we can fail fast rather than during a bosh deployment.
# Arguments:
#   Path to manifest yaml file (i.e. deployment manifest or cloud config).
#   Optional array of flags.
# Returns:
#   0 if updated, non-zero on error.
#######################################
function validate_bosh_interpolation() {
  local manifest_yaml_file="$1"
  shift
  #TMPDIR="${BBL_STATE_DIR}"/tmp
  #mkdir $TMPDIR
  #ls -la $BBL_STATE_DIR
  TMPDIR=""
  TMPDIR=$(mktemp -d -t "bosh_int".XXXXXX)
  trap 'rm -rf ${TMPDIR}' INT TERM QUIT EXIT

  set -x
  bosh int "$manifest_yaml_file" "$@" # just to see output
  set +x
  interpolation_result="$TMPDIR/interpolation_result.yml"
  bosh int "${manifest_yaml_file}" "$@" > "${interpolation_result}"
  
  exclude_list="${TMPDIR}"/exclude_list.txt
  touch "${exclude_list}"
  credhub_exclusions="${BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS:-""}"

  echo "Checking for user-specified CredHub exclusions to filter out of bosh interpolation validation"
  echo "NOTE: if this is blank it means the calling script did not provide the exclusions via env var BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS"
  echo "CredHub exclusions found (will be blank if none provided): $credhub_exclusions"
  for exclusion in $credhub_exclusions;do
    echo "(($exclusion))" >> "${exclude_list}"
  done
  interpolation_result_after_exclusions="${TMPDIR}"/interpolation_result_after_exclusions.yml
  grep -v -f "${exclude_list}" < "${interpolation_result}" > "${interpolation_result_after_exclusions}"
  echo "Verifying bosh interpolation.."
  if ! grep "((" < "${interpolation_result_after_exclusions}";then
    echo "Validation of bosh interpolation successful"
    return 0
  else
    grep "((" < "${interpolation_result_after_exclusions}"
    echo "Validation of bosh interpolation failed :("
    echo "NOTE: For expected variables meant to come from CredHub, pass in the env var BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS (e.g. export BOSH_INTERPOLATE_VALIDATION_CREDHUB_VAR_EXCLUSIONS="/concourse/main/concourse_worker_key /concourse/main/concourse_tsa_host_key.public_key")"
    err_fatal "Found variables that were not interpolated. See output above for details"
  fi

}

function err_fatal() {
  echo "[FATAL] $(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

function cp_ops_file_to_state_dir(){
  local source_ops_file_in_bosh_ops_files_dir="$1"
  filename="${source_ops_file_in_bosh_ops_files_dir}"
  prefix_to_ensure_file_processed_last="${STATE_OPS_FILE_PREFIX}"
  source_ops_file="${BOSH_OPS_FILES_DIR}"/"${filename}"
  dest_ops_file_name="${prefix_to_ensure_file_processed_last}""${filename}"
  dest_ops_file="${STATE_OPS_FILES_DIR}"/"${dest_ops_file_name}"
  if [ ! -f "${dest_ops_file}" ];then
    echo "Copying provided ops file to state repo. ${source_ops_file} to ${dest_ops_file}"
    mkdir -p "${STATE_OPS_FILES_DIR}"
    cp "${source_ops_file}" "${dest_ops_file}"
    cat "${dest_ops_file}"
  else
    echo "File already exists. Skipping. Found ${dest_ops_file}"
  fi
}

function are_you_sure_destroy(){
  read -r -p "Are You Sure? This will destroy your environment completely [Y/n] " input
   
  case $input in
      [yY][eE][sS]|[yY])
   echo "Continuing with destruction"
   ;;
      [nN][oO]|[nN])
   echo "Bailing out. Bye.."
   exit 1
         ;;
      *)
   echo "Invalid input..."
   exit 1
   ;;
  esac
}

function bosh_delete_all_deployments(){
  are_you_sure_destroy
  if ! bosh_cmd deployments --json ;then
    err_fatal "Cannot retrieve deployments"
  fi

  for deployment_name in $(bosh -e "$BOSH_ENV_ALIAS" -n deployments --json | jq -r '.Tables[0].Rows[].name'); do
    bosh_cmd delete-deployment -d "${deployment_name}"
    sleep 1m
  done
}

function store_bucc_interpolation_result(){

  echo "Persisting the actual bosh.yml interpolation as ${STATE_BUCC_CURRENT_YAML}"
  bucc_cmd int | sed '/BEGIN RSA PRIVATE KEY/,/END RSA PRIVATE KEY/{//!d;};' | sed '/BEGIN CERTIFICATE/,/END CERTIFICATE/{//!d;};' > "${STATE_BUCC_CURRENT_YAML}"
}
