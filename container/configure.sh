#!/usr/bin/env bash

# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Due to the GCE custom metadata size limit, we split the entire script into two
# files configure.sh and configure-helper.sh. The functionality of downloading
# kubernetes configuration, manifests, docker images, and binary files are
# put in configure.sh, which is uploaded via GCE custom metadata.

set -o errexit
set -o nounset
set -o pipefail

### Hardcoded constants

DEFAULT_CNI_VERSION='v1.4.0-gke.3'
DEFAULT_CNI_HASH_LINUX_AMD64='44a461d6446ce82f9f4b8e81fd95c7b86ca1c4e4c34825b8a1dc0533073e0655750c4b9d39d7d2b742eb0146e0ee9265351d5f04b8e04e953d5cf8fefce33cf9'
DEFAULT_CNI_HASH_LINUX_ARM64='9c299d26ea6abc9780ac0245196587500afa2b4a4bf5fc855a52bb9cf39e4cb36364bba27e29ca5067ba93b5f8abbbc4d2a01a7c6c62a07d3e537a1be3ce3038'

DEFAULT_NPD_VERSION='v0.8.19-12-g5efc8884-gke.1'
DEFAULT_NPD_HASH_AMD64='c9d652c18ab2e90f5b0de0384f0af7d9bb0abf14c7120828fdb8f1aad7950178195547cf9be49d4647e86366d2f4a462d2b9d3d7550840c48545a2268f97abd2'
DEFAULT_NPD_HASH_ARM64='4520a9642525f6f271b76cfcb23a0d6a385860098d247aa63bc68b6b1e5aca198b50fd03c6354c8109e7f816260b47b4658ee70c617460dbb0263b7a7977e5a8'

NPD_CUSTOM_PLUGINS_VERSION="v1.0.20"
NPD_CUSTOM_PLUGINS_TAR_AMD64_HASH="0907d1949013577cb13f90d10274e37f4ff6962fb97d23454b38562966f31d0d50da960278da7353215ecc6ec777b7a87c2972f3244ba7a8c9444282cc5dd84c"
NPD_CUSTOM_PLUGINS_TAR_ARM64_HASH="773062478605e5bf6d65c7e1374bff6b6cb2a99fc59ea46472c2fe4b15451f8547c740495961f1a9c50077ea67d16e32106733326d7e197dac60a07d8b05a375"

DEFAULT_CRICTL_VERSION='v1.28.0-gke.1'
DEFAULT_CRICTL_AMD64_SHA512='46387d29d2d79efe0fc0b83df3de6f3d9b00d1477d9765cd8e9a5d30b234d6d9b5bfd408bf4f7741c75a7bc0163b362156475e941c6387476866f0e69bae6ce3'
DEFAULT_CRICTL_ARM64_SHA512='bb6505766cd294905bad7c8af11133a8f712e1a6806cf39c6eadcfadb5fcd608efdbf8e2abdf21e5061b4ff3bc5778e76005da64f7d91f4b2e5c543ebd833b54'
DEFAULT_MOUNTER_ROOTFS_VERSION='v1.0.0'
DEFAULT_MOUNTER_ROOTFS_TAR_AMD64_SHA512='631330b7fa911d67e400b1d014df65a7763667d4afd4ecefe11a4a89dc9b8be626e5610d53b536c255a3ab488408ab2da8a0699d9fdad280cb3aa24bc2f30ab0'
DEFAULT_MOUNTER_ROOTFS_TAR_ARM64_SHA512='83cf9ab7961627359654131abd2d4c4b72875d395c50cda9e417149b2eb53b784dfe5c2f744ddbccfe516e36dd64c716d69d161d8bc8b4f42a9207fe676d0bc1'

RIPTIDE_FUSE_VERSION="v0.214.3.patch"
RIPTIDE_FUSE_ARM64_SHA512='fe37b8778f6b503feadab0a3a1be58f3f23d2f90621d9ddaf700ba90e0c738049575ed94a3580a17a034469788becbea7b9d03044fce052f2486b26df3d3f66c'
RIPTIDE_FUSE_BIN_ARM64_SHA512='bbf0adccf0f704545e2deda35ffd879a469e4a431c9ca8b953985dcbc65a6cddfbf720ed8f139c77b29baadb86c7d9e2289a0e1e8d78106e0fa3f14ab8787a7b'
RIPTIDE_FUSE_AMD64_SHA512='fdec86c923e146d1935197a503b2faff594172ac700da0cc1b124cca08ed5ae4cfc8ab6cfee36add4caf89504a4ef0d07ae5f9e97b0d1b82b0733eec06ff4dbe'
RIPTIDE_FUSE_BIN_AMD64_SHA512='ffafef3e6a05e2dbf16c44c4472bb37f04b4ad645c7b6af175461680ece661fe6029e84d3f997e556f9497d844be4da287558d7c25df86fbb215bed3cad612b0'

RIPTIDE_SNAPSHOTTER_VERSION="v1.30-2"
RIPTIDE_SNAPSHOTTER_SHA512='f88cd082bd3dd80a9b9315e3ea71826115c7afc8aa77d0c7449ad9dd9337921071dd919024ab3db8dc45c84d9f0628614704f692bc6d0c8ac0467d0fc1ec7cc4'
RIPTIDE_SNAPSHOTTER_BIN_ARM64_SHA512='01602fb932b8c1d632da35578dde7eadf2a5c426c060b067c4eefe945be9d0e3174834dd8062cb492e283420ef06295ea11771873289db6f4f5e5f9950fcfdb7'
RIPTIDE_SNAPSHOTTER_BIN_AMD64_SHA512='78347dfc69ad428e7b03bc77c41de92930f78e0fb40a14db5b01d2837acc89c426fe0efb6bca140f4cd4e33ca828960c83c4df43eabe4f887726eea0b4e3f36d'

AUTH_PROVIDER_GCP_VERSION="v0.0.2-gke.4"
AUTH_PROVIDER_GCP_HASH_LINUX_AMD64="156058e5b3994cba91c23831774033e0d505d6d8b80f43541ef6af91b320fd9dfaabe42ec8a8887b51d87104c2b57e1eb895649d681575ffc80dd9aee8e563db"
AUTH_PROVIDER_GCP_HASH_LINUX_ARM64="1aa3b0bea10a9755231989ffc150cbfa770f1d96932db7535473f7bfeb1108bafdae80202ae738d59495982512e716ff7366d5f414d0e76dd50519f98611f9ab"

###

# Backend endpoints (configurable for TPC).
# May be overridden when kube-env is sourced.
#
# NOTE: Endpoints should behave exactly like a GDU (Google Default Universe)
# endpoint. E.g., An alternative `STORAGE_ENDPOINT` must have the same buckets
# and paths as the `storage.googleapis.com` that this script depends on.
STORAGE_ENDPOINT="${STORAGE_ENDPOINT:-https://storage.googleapis.com}"
PGA_ENDPOINT="${PGA_ENDPOINT:-private.googleapis.com}"
KUBE_DOCKER_REGISTRY="${KUBE_DOCKER_REGISTRY:-gke.gcr.io}"

# Whether to configure private google access or not (defaults to true).
# May be overridden when kube-env is sourced.
CONFIGURE_PGA="${CONFIGURE_PGA:-true}"

# Standard curl flags.
CURL_FLAGS='--fail --silent --show-error --retry 5 --retry-delay 3 --connect-timeout 10 --retry-connrefused'

# This version needs to be the same as in gke/cluster/gce/gci/configure-helper.sh
GKE_CONTAINERD_INFRA_CONTAINER="pause:3.8@sha256:880e63f94b145e46f1b1082bb71b85e21f16b99b180b9996407d61240ceb9830"

# Set max reboot retry 3 plus the inital boot count
MAX_BOOT_COUNT="${MAX_BOOT_COUNT:-4}"

function set-broken-motd {
  cat > /etc/motd <<EOF
Broken (or in progress) Kubernetes node setup! Check the cluster initialization status
using the following commands.

Master instance:
  - sudo systemctl status kube-master-installation
  - sudo systemctl status kube-master-configuration

Node instance:
  - sudo systemctl status kube-node-installation
  - sudo systemctl status kube-node-configuration
EOF
}

# A function that fetches a GCE metadata value and echoes it out.
# Args:
#   $1 : URL path after /computeMetadata/v1/ (without heading slash).
#   $2 : An optional default value to echo out if the fetch fails.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function get-metadata-value {
  local default="${2:-}"

  local status
  # shellcheck disable=SC2086
  curl ${CURL_FLAGS} \
    -H 'Metadata-Flavor: Google' \
    "http://metadata/computeMetadata/v1/${1}" \
  || status="$?"
  status="${status:-0}"

  if [[ "${status}" -eq 0 || -z "${default}" ]]; then
    return "${status}"
  else
    echo "${default}"
  fi
}

# A function to fetch kube-env from GCE metadata server
# or using hurl on the master if available
function download-kube-env {
  (
    umask 077
    local kube_env_path="/tmp/kube-env.yaml"
    if [[ "${KUBERNETES_MASTER:-}" == "true" && $(use-hurl) = "true" ]]; then
      local kube_env_path="${KUBE_HOME}/kube-env.yaml"
      download-kube-env-hurl "${kube_env_path}"
    else
      local meta_path="http://metadata.google.internal/computeMetadata/v1/instance/attributes/kube-env"
      echo "Downloading kube-env via GCE metadata from ${meta_path} to ${kube_env_path}"
      # shellcheck disable=SC2086
      retry-forever 10 curl ${CURL_FLAGS} \
        -H "X-Google-Metadata-Request: True" \
        -o "${kube_env_path}" \
        "${meta_path}"
    fi

    # Convert the yaml format file into a shell-style file.
    eval "$(python3 -c '''
import pipes,sys,yaml
items = yaml.load(sys.stdin, Loader=yaml.BaseLoader).items()
for k, v in items:
    print("readonly {var}={value}".format(var=k, value=pipes.quote(str(v))))
''' < "${kube_env_path}" > "${KUBE_HOME}/kube-env")"

    # Leave kube-env if we are a master
    if [[ "${KUBERNETES_MASTER:-}" != "true" ]]; then
      rm -f "${kube_env_path}"
    fi
  )
}

# A function to pull kube-env from HMS using hurl
function download-kube-env-hurl {
  local -r kube_env_path="$1"
  local -r endpoint=$(get-metadata-value "instance/attributes/gke-api-endpoint")
  local -r kube_env_hms_path=$(get-metadata-value "instance/attributes/kube-env-path")

  echo "Downloading kube-env via hurl from ${kube_env_hms_path} to ${kube_env_path}"
  retry-forever 30 ${KUBE_HOME}/bin/hurl --hms_address $endpoint \
    --dst "${kube_env_path}" \
    "${kube_env_hms_path}"
  chmod 600 "${kube_env_path}"
}

function download-kubelet-config {
  local -r dest="$1"
  echo "Downloading Kubelet config file, if it exists"
  # Fetch kubelet config file from GCE metadata server.
  (
    umask 077
    local -r tmp_kubelet_config="/tmp/kubelet-config.yaml"
    # shellcheck disable=SC2086
    retry-forever 10 curl ${CURL_FLAGS} \
      -H "X-Google-Metadata-Request: True" \
      -o "${tmp_kubelet_config}" \
      http://metadata.google.internal/computeMetadata/v1/instance/attributes/kubelet-config
    # only write to the final location if curl succeeds
    mv "${tmp_kubelet_config}" "${dest}"
  )
}

# A function to pull kube-master-certs from HMS using hurl
function download-kube-master-certs-hurl {
  local -r endpoint=$(get-metadata-value "instance/attributes/gke-api-endpoint")
  local -r tmp_kube_master_certs_path="/tmp/kube-master-certs.yaml"
  local -r kube_master_certs_path="${KUBE_HOME}/kube-master-certs"
  local -r kube_master_certs_hms_path=$(get-metadata-value "instance/attributes/kube-master-certs-path")

  echo "Downloading kube-master-certs via hurl from ${kube_master_certs_hms_path} to ${tmp_kube_master_certs_path}"
  retry-forever 30 ${KUBE_HOME}/bin/hurl --hms_address $endpoint \
    --dst "${tmp_kube_master_certs_path}" \
    "${kube_master_certs_hms_path}"

  # Convert the yaml format file into a shell-style file.
  eval "$(python3 -c '''
import pipes,sys,yaml
items = yaml.load(sys.stdin, Loader=yaml.BaseLoader).items()
for k, v in items:
    print("readonly {var}={value}".format(var=k, value=pipes.quote(str(v))))
''' < "${tmp_kube_master_certs_path}" > "${kube_master_certs_path}")"

  # Remove the temp certs and strip perms for other users
  rm -f "${tmp_kube_master_certs_path}"
  chmod 600 "${kube_master_certs_path}"
}

function validate-hash {
  local -r file="$1"
  local -r expected="$2"

  actual_sha1=$(sha1sum "${file}" | awk '{ print $1 }') || true
  actual_sha512=$(sha512sum "${file}" | awk '{ print $1 }') || true
  if [[ "${actual_sha1}" != "${expected}" ]] && [[ "${actual_sha512}" != "${expected}" ]]; then
    echo "== ${file} corrupted, sha1 ${actual_sha1}/sha512 ${actual_sha512} doesn't match expected ${expected} =="
    return 1
  fi
}

# Get default service account credentials of the VM.
GCE_METADATA_INTERNAL="http://metadata.google.internal/computeMetadata/v1/instance"
function get-credentials {
  # shellcheck disable=SC2086
  curl ${CURL_FLAGS} \
    -H "Metadata-Flavor: Google" \
    "${GCE_METADATA_INTERNAL}/service-accounts/default/token" \
  | python3 -c 'import sys; import json; print(json.loads(sys.stdin.read())["access_token"])'
}

function valid-storage-scope {
  # shellcheck disable=SC2086
  curl ${CURL_FLAGS} \
    -H "Metadata-Flavor: Google" \
    "${GCE_METADATA_INTERNAL}/service-accounts/default/scopes" \
  | grep -E "auth/devstorage|auth/cloud-platform"
}

# A function that returns "true" if hurl should be used, "false" otherwise.
function use-hurl {
  local -r enable_hms_read=${ENABLE_HMS_READ:-$(get-metadata-value "instance/attributes/enable_hms_read")}
  local result="false"

  if [[ -f "${KUBE_HOME}/bin/hurl" && "${enable_hms_read}" == "true" ]]; then
    result="true"
  fi
  echo $result
}

# Retry a download until we get it. Takes a hash and a set of URLs.
#
# $1 is the sha512/sha1 hash of the URL. Can be "" if the sha512/sha1 hash is unknown.
# $2+ are the URLs to download.
# env var FORCE_USE_CREDENTIAL indicates whether to force using credential.
function download-or-bust {
  if [[ "${ARTIFACT_DOWNLOAD_RESTRICTED:-}" == "true" ]]; then
    echo "Cannot download: $* as downloading is restricted, exiting"
    exit 1
  fi

  local -r hash="$1"
  shift 1

  while true; do
    for url in "$@"; do
      local file="${url##*/}"
      rm -f "${file}"
      # if the url belongs to GCS API we should use oauth2_token in the headers if the VM service account has storage scopes
      local curl_headers=""

      if [[ "$url" =~ ^${STORAGE_ENDPOINT}/.* ]] || [[ "${FORCE_USE_CREDENTIAL:-false}" == "true" ]] ; then
        local canUseCredentials=0

        echo "Getting the scope of service account configured for VM."
        if ! valid-storage-scope ; then
          canUseCredentials=1
          # this behavior is preserved for backward compatibility. We want to fail fast if SA is not available
          # and try to download without SA if scope does not exist on SA
          echo "No service account or service account without storage scope. Attempt to download without service account token."
        fi

        if [[ "${canUseCredentials}" == "0" ]] ; then
          echo "Getting the service account access token configured for VM."
          local access_token="";
          if access_token=$(get-credentials); then
            echo "Service account access token is received. Downloading ${url} using this token."
          else
            echo "Cannot get a service account token. Exiting."
            exit 1
          fi

          curl_headers=${access_token:+Authorization: Bearer "${access_token}"}
        fi
      fi
      if ! curl ${curl_headers:+-H "${curl_headers}"} -f --ipv4 -Lo "${file}" --connect-timeout 20 --retry 6 --retry-delay 10 --retry-connrefused "${url}"; then
        echo "== Failed to download ${url}. Retrying. =="
      elif [[ -n "${hash}" ]] && ! validate-hash "${file}" "${hash}"; then
        echo "== Hash validation of ${url} failed. Retrying. =="
      else
        if [[ -n "${hash}" ]]; then
          echo "== Downloaded ${url} (HASH = ${hash}) =="
        else
          echo "== Downloaded ${url} =="
        fi
        return
      fi
    done
  done
}

function record-preload-info {
  echo "$1,$2" >> "${KUBE_HOME}/preload_info"
  echo "Recording preload info for ${1} ${2}"
}

function is-preloaded {
  local -r key=$1
  local -r value=$2

  if ! grep -qs "${key},${value}" "${KUBE_HOME}/preload_info"; then
    if [[ "${ARTIFACT_DOWNLOAD_RESTRICTED:-}" == "true" ]]; then
      echo "No preload record found for ${key} and ${value} and downloading is restricted, exiting"
      exit 1
    fi
    if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
      echo "No preload record found for ${key} and ${value}"
    fi
    return 1
  fi
}

function is-ubuntu {
  [[ -f "/etc/os-release" && $(grep ^NAME= /etc/os-release) == 'NAME="Ubuntu"' ]]
}

function split-commas {
  echo -e "${1//,/'\n'}"
}

function remount-flexvolume-directory {
  local -r flexvolume_plugin_dir=$1
  mkdir -p "$flexvolume_plugin_dir"
  mount --bind "$flexvolume_plugin_dir" "$flexvolume_plugin_dir"
  mount -o remount,exec "$flexvolume_plugin_dir"
}

function install-gci-mounter-tools {
  CONTAINERIZED_MOUNTER_HOME="${KUBE_HOME}/containerized_mounter"
  if [[ -n "${MOUNTER_ROOTFS_VERSION:-}" ]]; then
      local -r mounter_rootfs_version="${MOUNTER_ROOTFS_VERSION}"
      local -r mounter_rootfs_tar_sha="${MOUNTER_ROOTFS_TAR_SHA512}"
  else
    local -r mounter_rootfs_version="${DEFAULT_MOUNTER_ROOTFS_VERSION}"
    case "${HOST_PLATFORM}/${HOST_ARCH}" in
      linux/amd64)
        local -r mounter_rootfs_tar_sha="${DEFAULT_MOUNTER_ROOTFS_TAR_AMD64_SHA512}"
        ;;
      linux/arm64)
        local -r mounter_rootfs_tar_sha="${DEFAULT_MOUNTER_ROOTFS_TAR_ARM64_SHA512}"
        ;;
      *)
        echo "Unrecognized version and platform/arch combination:"
        echo "$mounter_rootfs_version $HOST_PLATFORM/$HOST_ARCH"
        echo "Set MOUNTER_ROOTFS_VERSION and MOUNTER_ROOTFS_TAR_SHA512 to overwrite"
        exit 1
        ;;
    esac
  fi

  if is-preloaded "mounter" "${mounter_rootfs_tar_sha}"; then
    echo "mounter is preloaded."
    return
  fi

  echo "Downloading gci mounter tools."
  mkdir -p "${CONTAINERIZED_MOUNTER_HOME}"
  chmod a+x "${CONTAINERIZED_MOUNTER_HOME}"

  # Copy the mounter binary downloaded with the k8s binaries tar file
  cp "${KUBE_HOME}/kubernetes/server/bin/mounter" "${CONTAINERIZED_MOUNTER_HOME}/mounter"
  chmod a+x "${CONTAINERIZED_MOUNTER_HOME}/mounter"
  # Download the debian rootfs required for the mounter container
  mkdir -p "${CONTAINERIZED_MOUNTER_HOME}/rootfs"
  local -r mounter_rootfs_tar="containerized-mounter-${mounter_rootfs_version}_${HOST_PLATFORM}_${HOST_ARCH}.tar.gz"
  download-or-bust "${mounter_rootfs_tar_sha}" "${STORAGE_ENDPOINT}/gke-release/containerized-mounter/${mounter_rootfs_version}/${mounter_rootfs_tar}"
  mv "${KUBE_HOME}/${mounter_rootfs_tar}" "/tmp/${mounter_rootfs_tar}"
  tar xzf "/tmp/${mounter_rootfs_tar}" -C "${CONTAINERIZED_MOUNTER_HOME}/rootfs"
  rm "/tmp/${mounter_rootfs_tar}"
  mkdir -p "${CONTAINERIZED_MOUNTER_HOME}/rootfs/var/lib/kubelet"

  record-preload-info "mounter" "${mounter_rootfs_tar_sha}"
}

function docker-installed {
    if systemctl cat docker.service &> /dev/null ; then
        return 0
    else
        return 1
    fi
}

function disable_aufs() {
  # disable aufs module if aufs is loaded
  if lsmod | grep "aufs" &> /dev/null ; then
    sudo modprobe -r aufs
  fi
}

function detect_mtu {
  local MTU=1460
  if [[ "${DETECT_MTU:-}" == "true" ]];then
    local default_nic=$(ip route get 8.8.8.8 | sed -nr "s/.*dev ([^\ ]+).*/\1/p")
    if [ -f "/sys/class/net/$default_nic/mtu" ]; then
      MTU=$(cat /sys/class/net/$default_nic/mtu)
    fi
  fi
  echo $MTU
}

# This function cofigures docker. It has no conditional logic.
# It will restart docker service so new settings will be picked up.
# This method cannot be preloaded as the boot disk changes will not be persistet thru the reboots.
function assemble-docker-flags {
  # log the contents of the /etc/docker/daemon.json if already exists
  if [ -f /etc/docker/daemon.json ]; then
    echo "Contents of the old docker config"
    cat /etc/docker/daemon.json
  fi

  disable_aufs

  # COS and Ubuntu have different docker options configured as command line arguments.
  # Use systemctl show docker to see the full list of options.
  # When configuring Docker options you can use daemon.json or command line arguments
  # The same option cannot be configured by both, even if it is a list option and can be repeated in the command line multiple times.
  # This is why we are not simply configuring everything in daemon.json.

  local MTU="$(detect_mtu)"

  # options to be set on COS, registry-mirror is pre-configured on COS
  local os_specific_options="\"live-restore\": true,\
   \"storage-driver\": \"overlay2\",\
   \"mtu\": ${MTU},"

  if is-ubuntu; then
    # Ubuntu already have everthing set
    os_specific_options=""
  fi

  # Important setting: set docker0 cidr to private ip address range to avoid conflict with cbr0 cidr range ("bip": "169.254.123.1/24")
  cat > /etc/docker/daemon.json <<EOF
{
  "pidfile": "/var/run/docker.pid",
  "iptables": false,
  "ip-masq": false,
  "log-level": "warn",
  "bip": "169.254.123.1/24",
  "log-driver": "json-file",
  ${os_specific_options}
  "log-opts": {
      "max-size": "10m",
      "max-file": "5"
  }
}
EOF

  # Do not move to the daemon.json file for backward compatibility.
  # Command line and config file options cannot be both defined and custoemr customization may break.
  # insecure-registry setting was inherited from the past, see b/203231428. Keeping for backward compatibility.
  echo "DOCKER_OPTS=\"--registry-mirror=https://mirror.gcr.io --insecure-registry 10.0.0.0/8\"" > /etc/default/docker

  echo "Docker command line and configuration are updated. Restart docker to pick it up"
  systemctl restart docker
}

# Install node problem detector binary.
function install-node-problem-detector {
  if [[ -n "${NODE_PROBLEM_DETECTOR_VERSION:-}" ]]; then
      local -r npd_version="${NODE_PROBLEM_DETECTOR_VERSION}"
      local -r npd_hash="${NODE_PROBLEM_DETECTOR_TAR_HASH}"
  else
      local -r npd_version="${DEFAULT_NPD_VERSION}"
      case "${HOST_PLATFORM}/${HOST_ARCH}" in
        linux/amd64)
          local -r npd_hash="${DEFAULT_NPD_HASH_AMD64}"
          ;;
        linux/arm64)
          local -r npd_hash="${DEFAULT_NPD_HASH_ARM64}"
          ;;
        # no other architectures are supported currently.
        # Assumption is that this script only runs on linux,
        # see cluster/gce/windows/k8s-node-setup.psm1 for windows
        # https://github.com/kubernetes/node-problem-detector/releases/
        *)
          echo "Unrecognized version and platform/arch combination:"
          echo "$DEFAULT_NPD_VERSION $HOST_PLATFORM/$HOST_ARCH"
          echo "Set NODE_PROBLEM_DETECTOR_VERSION and NODE_PROBLEM_DETECTOR_TAR_HASH to overwrite"
          exit 1
          ;;
      esac
  fi
  local -r npd_tar="node-problem-detector-${npd_version}-${HOST_PLATFORM}_${HOST_ARCH}.tar.gz"

  if is-preloaded "${npd_tar}" "${npd_hash}"; then
    echo "${npd_tar} is preloaded."
    return
  fi

  echo "Downloading ${npd_tar}."
  local -r npd_release_path="${NODE_PROBLEM_DETECTOR_RELEASE_PATH:-${STORAGE_ENDPOINT}/gke-release}"
  download-or-bust "${npd_hash}" "${npd_release_path}/node-problem-detector/${npd_tar}"
  local -r npd_dir="${KUBE_HOME}/node-problem-detector"
  mkdir -p "${npd_dir}"
  tar xzf "${KUBE_HOME}/${npd_tar}" -C "${npd_dir}" --overwrite
  mv "${npd_dir}/bin"/* "${KUBE_BIN}"
  chmod a+x "${KUBE_BIN}/node-problem-detector"
  rmdir "${npd_dir}/bin"
  rm -f "${KUBE_HOME}/${npd_tar}"

  record-preload-info "${npd_tar}" "${npd_hash}"
}

# Install node problem detector custom plugins.
function install-npd-custom-plugins {
  local -r version="${NPD_CUSTOM_PLUGINS_VERSION}"
  case "${HOST_PLATFORM}/${HOST_ARCH}" in
    linux/amd64)
      local -r hash="${NPD_CUSTOM_PLUGINS_TAR_AMD64_HASH}"
      ;;
    linux/arm64)
      local -r hash="${NPD_CUSTOM_PLUGINS_TAR_ARM64_HASH}"
      ;;
    *)
      echo "Unrecognized version and platform/arch combination:"
      echo "$NPD_CUSTOM_PLUGINS_VERSION $HOST_PLATFORM/$HOST_ARCH"
      exit 1
  esac
  local -r tar="npd-custom-plugins-${version}-${HOST_PLATFORM}-${HOST_ARCH}.tar.gz"

  if is-preloaded "${tar}" "${hash}"; then
    echo "${tar} is preloaded."
    return
  fi

  echo "Downloading ${tar}."
  download-or-bust "${hash}" "${STORAGE_ENDPOINT}/gke-release/npd-custom-plugins/${version}/${tar}"
  local -r dir="${KUBE_HOME}/npd-custom-plugins"
  mkdir -p "${dir}"
  tar xzf "${KUBE_HOME}/${tar}" -C "${dir}" --overwrite
  local -r kube_bin_dir="${KUBE_HOME}/bin"
  cp -r "${dir}/bins"/* "${kube_bin_dir}"
  rm -f "${KUBE_HOME}/${tar}"

  record-preload-info "${tar}" "${hash}"
}

function install-cni-binaries {
  local -r cni_version=${CNI_VERSION:-$DEFAULT_CNI_VERSION}
  if [[ -n "${CNI_VERSION:-}" ]]; then
    local -r cni_hash="${CNI_HASH:-}"
  else
    local -r cni_hash_var="DEFAULT_CNI_HASH_${HOST_PLATFORM^^}_${HOST_ARCH^^}"
    local -r cni_hash="${!cni_hash_var}"
  fi

  local -r cni_tar="cni-plugins-${HOST_PLATFORM}-${HOST_ARCH}-${cni_version}.tgz"
  local -r cni_url="${STORAGE_ENDPOINT}/gke-release/cni-plugins/${cni_version}/${cni_tar}"

  if is-preloaded "${cni_tar}" "${cni_hash}"; then
    echo "${cni_tar} is preloaded."
    return
  fi

  echo "Downloading cni binaries"
  download-or-bust "${cni_hash}" "${cni_url}"
  local -r cni_dir="${KUBE_HOME}/cni"
  mkdir -p "${cni_dir}/bin"
  tar xzf "${KUBE_HOME}/${cni_tar}" -C "${cni_dir}/bin" --overwrite
  mv "${cni_dir}/bin"/* "${KUBE_BIN}"
  rmdir "${cni_dir}/bin"
  rm -f "${KUBE_HOME}/${cni_tar}"

  record-preload-info "${cni_tar}" "${cni_hash}"
}

# Install crictl binary.
# Assumptions: HOST_PLATFORM and HOST_ARCH are specified by calling detect_host_info.
function install-crictl {
  if [[ -n "${CRICTL_VERSION:-}" ]]; then
    local -r crictl_version="${CRICTL_VERSION}"
    local -r crictl_hash="${CRICTL_TAR_HASH}"
  else
    local -r crictl_version="${DEFAULT_CRICTL_VERSION}"
    case "${HOST_PLATFORM}/${HOST_ARCH}" in
      linux/amd64)
        local -r crictl_hash="${DEFAULT_CRICTL_AMD64_SHA512}"
        ;;
      linux/arm64)
        local -r crictl_hash="${DEFAULT_CRICTL_ARM64_SHA512}"
        ;;
      *)
        echo "Unrecognized version and platform/arch combination:"
        echo "$DEFAULT_CRICTL_VERSION $HOST_PLATFORM/$HOST_ARCH"
        echo "Set CRICTL_VERSION and CRICTL_TAR_HASH to overwrite"
        exit 1
    esac
  fi
  local -r crictl="crictl-${crictl_version}-${HOST_PLATFORM}-${HOST_ARCH}.tar.gz"

  # Create crictl config file.
  cat > /etc/crictl.yaml <<EOF
runtime-endpoint: ${CONTAINER_RUNTIME_ENDPOINT:-unix:///run/containerd/containerd.sock}
EOF

  if is-preloaded "${crictl}" "${crictl_hash}"; then
    echo "crictl is preloaded"
    return
  fi

  echo "Downloading crictl"
  local -r crictl_path="${STORAGE_ENDPOINT}/gke-release/cri-tools/${crictl_version}"
  download-or-bust "${crictl_hash}" "${crictl_path}/${crictl}"
  tar xf "${crictl}"
  mv crictl "${KUBE_BIN}/crictl"
  rm -f "${crictl}"

  record-preload-info "${crictl}" "${crictl_hash}"
}

function preload-pause-image {
  local -r pause_image="${KUBE_DOCKER_REGISTRY}/${GKE_CONTAINERD_INFRA_CONTAINER}"
  local pause_sha="${GKE_CONTAINERD_INFRA_CONTAINER#*@}"
  if [ -z "$pause_sha" ]; then
    echo "found no digest in GKE_CONTAINERD_INFRA_CONTAINER"
  else
    for img in $(ctr -n=k8s.io images list -q | grep "${pause_sha}"); do
      echo "pause image ${img} of the same version is preloaded, retagging"
      if [[ "${pause_image}" != "${img}" ]]; then
        ctr -n=k8s.io image tag --force ${img} ${pause_image}
      fi
      return
    done
  fi

  # preloading pause image. It will be used in preloader and will be
  # useful for staging builds where access_token is needed to pull the image
  local access_token="";

  if access_token=$(get-credentials); then
    ctr -n=k8s.io image pull --user="oauth2accesstoken:${access_token}" "${pause_image}"
  else
    echo "No access token. Pulling without it."
    ctr -n=k8s.io image pull "${pause_image}"
  fi
  pin-docker-image "pause"
}

function install-exec-auth-plugin {
  if [[ ! "${EXEC_AUTH_PLUGIN_URL:-}" ]]; then
      return
  fi
  local -r plugin_url="${EXEC_AUTH_PLUGIN_URL}"
  local -r plugin_hash="${EXEC_AUTH_PLUGIN_HASH}"

  if is-preloaded "gke-exec-auth-plugin" "${plugin_hash}"; then
    echo "gke-exec-auth-plugin is preloaded"
    return
  fi

  echo "Downloading gke-exec-auth-plugin binary"
  download-or-bust "${plugin_hash}" "${plugin_url}"
  mv "${KUBE_HOME}/gke-exec-auth-plugin" "${KUBE_BIN}/gke-exec-auth-plugin"
  chmod a+x "${KUBE_BIN}/gke-exec-auth-plugin"

  if [[ ! "${EXEC_AUTH_PLUGIN_LICENSE_URL:-}" ]]; then
      return
  fi
  local -r license_url="${EXEC_AUTH_PLUGIN_LICENSE_URL}"
  echo "Downloading gke-exec-auth-plugin license"
  download-or-bust "" "${license_url}"
  mv "${KUBE_HOME}/LICENSE" "${KUBE_BIN}/gke-exec-auth-plugin-license"

  record-preload-info "gke-exec-auth-plugin" "${plugin_hash}"
}

function install-kube-manifests {
  # Put kube-system pods manifests in ${KUBE_HOME}/kube-manifests/.
  local dst_dir="${KUBE_HOME}/kube-manifests"
  mkdir -p "${dst_dir}"
  local manifests_tar_urls
  while IFS= read -r url; do
    manifests_tar_urls+=("$url")
  done < <(split-commas "${KUBE_MANIFESTS_TAR_URL}")
  local -r manifests_tar="${manifests_tar_urls[0]##*/}"
  if [ -n "${KUBE_MANIFESTS_TAR_HASH:-}" ]; then
    local -r manifests_tar_hash="${KUBE_MANIFESTS_TAR_HASH}"
  else
    echo "Downloading k8s manifests hash (not found in env)"
    download-or-bust "" "${manifests_tar_urls[@]/.tar.gz/.tar.gz.sha512}"
    local -r manifests_tar_hash=$(cat "${manifests_tar}.sha512")
  fi

  if is-preloaded "${manifests_tar}" "${manifests_tar_hash}"; then
    echo "${manifests_tar} is preloaded."
    return
  fi

  echo "Downloading k8s manifests tar"
  download-or-bust "${manifests_tar_hash}" "${manifests_tar_urls[@]}"
  tar xzf "${KUBE_HOME}/${manifests_tar}" -C "${dst_dir}" --overwrite
  local -r kube_addon_registry="${KUBE_ADDON_REGISTRY:-k8s.gcr.io}"
  if [[ "${kube_addon_registry}" != "k8s.gcr.io" ]]; then
    find "${dst_dir}" \(-name '*.yaml' -or -name '*.yaml.in'\) -print0 | \
      xargs -0 sed -ri "s@(image:\s.*)k8s.gcr.io@\1${kube_addon_registry}@"
    find "${dst_dir}" \(-name '*.manifest' -or -name '*.json'\) -print0 | \
      xargs -0 sed -ri "s@(image\":\s+\")k8s.gcr.io@\1${kube_addon_registry}@"
  fi
  cp "${dst_dir}/kubernetes/gci-trusty/gci-configure-helper.sh" "${KUBE_BIN}/configure-helper.sh"
  cp "${dst_dir}/kubernetes/gci-trusty/configure-kubeapiserver.sh" "${KUBE_BIN}/configure-kubeapiserver.sh"
  if [[ -e "${dst_dir}/kubernetes/gci-trusty/gke-internal-configure-helper.sh" ]]; then
    cp "${dst_dir}/kubernetes/gci-trusty/gke-internal-configure-helper.sh" "${KUBE_BIN}/"
  fi
  if [[ -e "${dst_dir}/kubernetes/gci-trusty/node-registration-checker.sh" ]]; then
    cp "${dst_dir}/kubernetes/gci-trusty/node-registration-checker.sh" "${KUBE_BIN}/"
  fi
  cp "${dst_dir}/kubernetes/gci-trusty/health-monitor.sh" "${KUBE_BIN}/health-monitor.sh"
  cp "${dst_dir}/kubernetes/gci-trusty/networkd-monitor.sh" "${KUBE_BIN}/networkd-monitor.sh"

  rm -f "${KUBE_HOME}/${manifests_tar}"
  rm -f "${KUBE_HOME}/${manifests_tar}.sha512"

  record-preload-info "${manifests_tar}" "${manifests_tar_hash}"
}

# Installs hurl to ${KUBE_HOME}/bin/hurl if not already installed.
function install-hurl {
  cd "${KUBE_HOME}"

  local -r hurl_bin="hurl"
  local -r hurl_gcs_att="instance/attributes/hurl-gcs-url"
  local -r hurl_gcs_url=${HURL_GCS_URL:-$(get-metadata-value "${hurl_gcs_att}")}
  local -r hurl_hash=${HURL_HASH:-$(get-metadata-value "instance/attributes/hurl-bin-hash")}

  ### Fallback to old logic in case hurl_hash is not set
  # extracting version from url, example:
  # $ echo "https://storage.googleapis.com/gke-master-startup/hurl/gke_master_hurl_20230824.00_p0/hurl" | sed -n 's/.*gke_master_hurl_\(.*\)\/hurl/\1/p'
  # 20230824.00_p0
  local -r hurl_version=$(echo "${hurl_gcs_url}" | sed -n 's/.*gke_master_hurl_\(.*\)\/hurl/\1/p')

  local -r hurl_preload_digest=${hurl_hash:-$hurl_version}

  if is-preloaded "${hurl_bin}" "${hurl_preload_digest}"; then
    echo "install-hurl: hurl already installed"
    return
  fi

  if [[ -z "${hurl_gcs_url}" ]]; then
    # URL not present in GCE Instance Metadata
    echo "install-hurl: Unable to find GCE metadata ${hurl_gcs_att}"
    return
  fi

  # Download hurl binary from a GCS bucket.
  echo "install-hurl: Installing hurl from ${hurl_gcs_url} ... "
  FORCE_USE_CREDENTIAL=true download-or-bust "${hurl_hash}" "${hurl_gcs_url}"
  if [[ -f "${KUBE_HOME}/${hurl_bin}" ]]; then
    chmod a+x ${KUBE_HOME}/${hurl_bin}
    mv "${KUBE_HOME}/${hurl_bin}" "${KUBE_BIN}/${hurl_bin}"
    echo "install-hurl: hurl installed to ${KUBE_BIN}/${hurl_bin}"
    record-preload-info "${hurl_bin}" "${hurl_preload_digest}"
    return
  fi
}

function install-k8s-pki {
    local -r k8s_pki_url="${STORAGE_ENDPOINT}/${K8S_PKI_GCS_PATH}"
    local -r k8s_pki_hash="${K8S_PKI_HASH}"

    if is-preloaded "k8s_pki" "${k8s_pki_hash}"; then
      echo "k8s_pki is preloaded"
      return
    fi

    echo "Downloading k8s_pki binary"
    download-or-bust "${k8s_pki_hash}" "${k8s_pki_url}"
    mv "${KUBE_HOME}/k8s_pki" "${KUBE_BIN}/k8s_pki"
    chmod a+x "${KUBE_BIN}/k8s_pki"

    echo "Record k8s_pki preload info"
    record-preload-info "k8s_pki" "${k8s_pki_hash}"
}


function install-auger {
  echo "Downloading auger binary"
  if [[ -f "${KUBE_HOME}/bin/auger" ]]; then
    echo "auger is already installed"
    return
  fi
  AUGER_STORE_PATH="${AUGER_STORE_PATH:-${STORAGE_ENDPOINT}/gke-release-staging/auger}"
  AUGER_VERSION="${AUGER_VERSION:-v1.0.0-gke.1}"
  download-or-bust "" "${AUGER_STORE_PATH}/${AUGER_VERSION}/auger.sha1"
  sha1="$(cat auger.sha1)"
  readonly sha1 # Declare readonly separately to avoid masking error values.
  rm -f "auger.sha1"
  download-or-bust "${sha1}" "${AUGER_STORE_PATH}/${AUGER_VERSION}/auger"
  mv "${KUBE_HOME}/auger" "${KUBE_HOME}/bin/auger"
  chmod a+x "${KUBE_HOME}/bin/auger"
  record-preload-info "auger" "${sha1}"
}

# Extract etcdctl binary from etcd image.
function install-etcdctl {
  echo "Installing etcdctl binary"
  if [[ -f "${KUBE_HOME}/bin/etcdctl" ]]; then
    echo "etcdctl is already installed"
    return
  fi
  local -r etcd_image="gcr.io/gke-master-images/etcd:${ETCDCTL_VERSION}"
  container_id="$(docker create "${etcd_image}" sh)"
  readonly containerId
  docker cp "${container_id}:usr/local/bin/etcdctl" "${KUBE_HOME}/bin/etcdctl"
  chmod a+x "${KUBE_HOME}/bin/etcdctl"
  docker rm "${container_id}"
  docker rmi "${etcd_image}"
}

function install-gcfsd {
  echo "Downloading Riptide FUSE client"
  if is-preloaded "gcfsd" "${RIPTIDE_FUSE_VERSION}"; then
    echo "gcfsd is preloaded."
    return
  fi

  if [[ "${HOST_ARCH}" == "arm64" ]]; then
    RIPTIDE_FUSE_STORE_PATH="${STORAGE_ENDPOINT}/gke-release/gcfsd/${RIPTIDE_FUSE_VERSION}/arm64"
    TAR_SHA="${RIPTIDE_FUSE_ARM64_SHA512}"
    BIN_SHA="${RIPTIDE_FUSE_BIN_ARM64_SHA512}"
  else
    RIPTIDE_FUSE_STORE_PATH="${STORAGE_ENDPOINT}/gke-release/gcfsd/${RIPTIDE_FUSE_VERSION}"
    TAR_SHA="${RIPTIDE_FUSE_AMD64_SHA512}"
    BIN_SHA="${RIPTIDE_FUSE_BIN_AMD64_SHA512}"
  fi

  echo "Downloading tarball for gcfsd"
  download-or-bust "${TAR_SHA}" "${RIPTIDE_FUSE_STORE_PATH}/gcfsd.tar.gz"

  download-or-bust "${BIN_SHA}" "${RIPTIDE_FUSE_STORE_PATH}/gcfsd"
  mv "${KUBE_HOME}/gcfsd" "${KUBE_HOME}/bin/gcfsd"
  chmod a+x "${KUBE_HOME}/bin/gcfsd"
  record-preload-info "gcfsd" "${RIPTIDE_FUSE_VERSION}"
}

function install-riptide-snapshotter {
  echo "Downloading Riptide snapshotter"
  if is-preloaded "containerd-gcfs-grpc" "${RIPTIDE_SNAPSHOTTER_VERSION}"; then
    echo "containerd-gcfs-grpc is preloaded."
    return
  fi
  RIPTIDE_SNAPSHOTTER_STORE_PATH="${STORAGE_ENDPOINT}/gke-release/gcfs-snapshotter/${RIPTIDE_SNAPSHOTTER_VERSION}"

  echo "Downloading tarball for riptide-snapshotter"
  download-or-bust "${RIPTIDE_SNAPSHOTTER_SHA512}" "${RIPTIDE_SNAPSHOTTER_STORE_PATH}/containerd-gcfs-grpc.tar.gz"

  if [[ "${HOST_ARCH}" == "arm64" ]]; then
    RIPTIDE_SNAPSHOTTER_BINARY="containerd-gcfs-grpc-arm64"
    RIPTIDE_SNAPSHOTTER_BIN_SHA512="${RIPTIDE_SNAPSHOTTER_BIN_ARM64_SHA512}"
  else
    RIPTIDE_SNAPSHOTTER_BINARY="containerd-gcfs-grpc"
    RIPTIDE_SNAPSHOTTER_BIN_SHA512="${RIPTIDE_SNAPSHOTTER_BIN_AMD64_SHA512}"
  fi

  download-or-bust "${RIPTIDE_SNAPSHOTTER_BIN_SHA512}" "${RIPTIDE_SNAPSHOTTER_STORE_PATH}/${RIPTIDE_SNAPSHOTTER_BINARY}"
  mv "${KUBE_HOME}/${RIPTIDE_SNAPSHOTTER_BINARY}" "${KUBE_HOME}/bin/containerd-gcfs-grpc"
  chmod a+x "${KUBE_HOME}/bin/containerd-gcfs-grpc"
  record-preload-info "containerd-gcfs-grpc" "${RIPTIDE_SNAPSHOTTER_VERSION}"
}

# Install Riptide FUSE client and Riptide snapshotter
function install-riptide {
  install-gcfsd
  install-riptide-snapshotter
}

function install-auth-provider-gcp {
  case "${HOST_ARCH}" in
    amd64)
      local -r auth_provider_gcp_hash="${AUTH_PROVIDER_GCP_HASH_LINUX_AMD64}"
      ;;
    arm64)
      local -r auth_provider_gcp_hash="${AUTH_PROVIDER_GCP_HASH_LINUX_ARM64}"
      ;;
    *)
      echo "Unrecognized version and platform/arch combination: ${HOST_PLATFORM}/${HOST_ARCH}"
      exit 1
  esac

  if is-preloaded "auth-provider-gcp" "${auth_provider_gcp_hash}"; then
    echo "auth-provider-gcp is preloaded."
    return
  fi

  local -r auth_provider_storage_url="${STORAGE_ENDPOINT}/gke-release/auth-provider-gcp/${AUTH_PROVIDER_GCP_VERSION}/${HOST_PLATFORM}_${HOST_ARCH}/auth-provider-gcp"
  echo "Downloading auth-provider-gcp ${auth_provider_storage_url}" .
  download-or-bust "${auth_provider_gcp_hash}" "${auth_provider_storage_url}"

  # Keep in sync with --image-credential-provider-bin-dir in cloud/kubernetes/distro/legacy/kube_env.go
  mv "${KUBE_HOME}/auth-provider-gcp" "${KUBE_BIN}"
  chmod a+x "${KUBE_BIN}/auth-provider-gcp"

  record-preload-info "auth-provider-gcp" "${auth_provider_gcp_hash}"
}

function download-gvisor-installer {
  local -r installer_image_hash=$1
  local -r installer_image="${KUBE_DOCKER_REGISTRY}/gke-gvisor-installer@sha256:${installer_image_hash}"
  if access_token=$(get-credentials); then
    "${KUBE_BIN}/crictl" pull --creds "oauth2accesstoken:${access_token}" "${installer_image}"
  else
    "${KUBE_BIN}/crictl" pull "${installer_image}"
  fi
}

function configure-cgroup-mode {
  if which cgroup_helper > /dev/null 2>&1; then
    if [[ "${CGROUP_MODE:-}" == "v1" ]] && cgroup_helper show | grep -q 'unified'; then
      cgroup_helper set hybrid
      echo "set cgroup config to hybrid, now rebooting..."
      reboot
    elif [[ "${CGROUP_MODE:-}" == "v2" ]] && cgroup_helper show | grep -q 'hybrid'; then
      cgroup_helper set unified
      echo "set cgroup config to unified, now rebooting..."
      reboot
    fi
  fi
}

# To improve the shieded VM reliability b/327650100
function check-tpm-file {
  if [[ -z "${TPM_BOOTSTRAP_KEY:-}" ]]; then
    echo "TPM_BOOTSTRAP_KEY is empty, thus vTPM is disabled, skip tpm file check"
    return 0
  else
    echo "TPM_BOOTSTRAP_KEY is not empty, thus vTPM is enabled, checking tpm file"
    if [[ -e "/dev/tpm0" ]]; then
      echo "/dev/tpm0 exists."
      return 0
    else
      echo "/dev/tpm0 doesn't exist."
      return 1
    fi
  fi
}

function detect-reboot-needed {
  # Exit if it is on the master
  if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
    return
  fi

  if [[ "${ENABLE_BEST_EFFORT_NODE_REBOOT:-}" == "true" ]]; then
    if check-tpm-file; then
      echo "TPM is present; continuing bootstrap..."
      return
    fi

    echo "TPM file check doesn't pass!"
    if ! REBOOT_HISTORY=$(journalctl --list-boots --quiet | wc -l); then
      echo "skip reboot attempt due to the journalctl error"
      return
    fi
    if [[ $(($REBOOT_HISTORY)) -gt ${MAX_BOOT_COUNT} ]]; then
      echo "best effort reboot attempt ${REBOOT_HISTORY} exceed ${MAX_BOOT_COUNT}! stop rebooting!"
    else
      # write to a persistent file after reboot for NPD reporting event
      # used in npd-custom-plugins/configs/node-reboot-monitor.json
      mkdir -p /var/lib/gke
      echo '1' >> /var/lib/gke/best_effort_reboot_marker
      echo "best effort reboot attempt ${REBOOT_HISTORY}! rebooting..."
      reboot
    fi
  fi
}

# A helper function for loading a docker image. It keeps trying up to 5 times.
#
# $1: Full path of the docker image
function try-load-docker-image {
  local -r img=$1
  echo "Try to load docker image file ${img}"
  # Temporarily turn off errexit, because we don't want to exit on first failure.
  set +e
  local -r max_attempts=5
  local -i attempt_num=1

  if [[ "${CONTAINER_RUNTIME_NAME:-}" == "containerd" || "${CONTAINERD_TEST:-}"  == "containerd" ]]; then
    load_image_command=${LOAD_IMAGE_COMMAND:-ctr -n=k8s.io images import}
  else
    load_image_command="${LOAD_IMAGE_COMMAND:-}"
  fi

  # Deliberately word split load_image_command
  # shellcheck disable=SC2086
  until timeout 30 ${load_image_command} "${img}"; do
    if [[ "${attempt_num}" == "${max_attempts}" ]]; then
      echo "Fail to load docker image file ${img} using ${load_image_command} after ${max_attempts} retries. Exit!!"
      exit 1
    else
      attempt_num=$((attempt_num+1))
      sleep 5
    fi
  done
  # Re-enable errexit.
  set -e
}

# Loads kube-system docker images. It is better to do it before starting kubelet,
# as kubelet will restart docker daemon, which may interfere with loading images.
function load-docker-images {
  echo "Start loading kube-system docker images"
  local -r img_dir="${KUBE_HOME}/kube-docker-files"
  if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
    try-load-docker-image "${img_dir}/kube-apiserver.tar"
    try-load-docker-image "${img_dir}/kube-controller-manager.tar"
    try-load-docker-image "${img_dir}/kube-scheduler.tar"
  else
    try-load-docker-image "${img_dir}/kube-proxy.tar"
  fi
}

# A helper function for retagging a docker image with new tag and new registry.
# $1: Image prefix
# $2: Image tag
# $3: Destination tag
# $4: Destination registry
function retag-docker-image {
  local -r img_prefix=$1
  local -r img_tag=$2
  local -r dest_tag=$3
  local -r dest_registry=$4
  echo "Retagging all images with prefix: ${img_prefix} and tag: ${img_tag} with new tag: ${dest_tag} and new registry: ${dest_registry}"
  local src_img=""
  for src_img in $(ctr -n=k8s.io images list -q | grep "/${img_prefix}" | grep ":${img_tag}$"); do
    dest_img=${src_img/:${img_tag}/:${dest_tag}}
    dest_img=${dest_registry}/${dest_img##*/}
    if [[ "${dest_img}" != "${src_img}" ]]; then
      cmd="ctr -n=k8s.io image tag --force ${src_img} ${dest_img}"
      echo "Retag command: ${cmd}"
      ${cmd}
    fi
  done
}

# Retags kube-system docker images with passed in kube-apiserver/kubelet versions.
function retag-docker-images {
  echo "Start retagging kube-system docker images"
  local src_tag=""
  local dest_tag=""
  if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
    src_tag=$(cat /home/kubernetes/kube-docker-files/kube-apiserver.docker_tag)
    # Keep the tag the same unless overridden
    dest_tag="${src_tag}"
    if [[ -n "${KUBE_APISERVER_VERSION:-}" ]]; then
      # Docker tags cannot contain '+', make CI versions a valid docker tag.
      dest_tag=${KUBE_APISERVER_VERSION/+/_}
    fi
    retag-docker-image "kube-apiserver" "${src_tag}" "${dest_tag}" "${KUBE_DOCKER_REGISTRY}"
    retag-docker-image "kube-controller-manager" "${src_tag}" "${dest_tag}" "${KUBE_DOCKER_REGISTRY}"
    retag-docker-image "kube-scheduler" "${src_tag}" "${dest_tag}" "${KUBE_DOCKER_REGISTRY}"
  else
    src_tag=$(cat /home/kubernetes/kube-docker-files/kube-proxy.docker_tag)
    # Keep the tag the same unless overridden
    dest_tag="${src_tag}"
    if [[ -n "${KUBELET_VERSION:-}" ]]; then
      # Docker tags cannot contain '+', make CI versions a valid docker tag.
      dest_tag=${KUBELET_VERSION/+/_}
    fi
    retag-docker-image "kube-proxy" "${src_tag}" "${dest_tag}" "${KUBE_DOCKER_REGISTRY}"
  fi
}

function ensure-container-runtime {
  if [[ "${CONTAINER_RUNTIME}" == "docker" ]]; then
    echo "Dockershim is not supported. Container runtime must be set to containerd"
    exit 2
  fi
}

function pin-docker-image {
  local -r img_prefix=$1
  echo "Pinning: ${img_prefix}"
  for img in $(ctr -n=k8s.io images list -q | grep "/${img_prefix}"); do
    cmd="ctr -n k8s.io images label ${img} io.cri-containerd.pinned=pinned"
    ${cmd}
  done
}

function pin-docker-images {
  if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
    pin-docker-image "kube-apiserver"
    pin-docker-image "kube-controller-manager"
    pin-docker-image "kube-scheduler"
  else
    pin-docker-image "kube-proxy"
  fi
}

# Downloads kubernetes binaries and kube-system manifest tarball, unpacks them,
# and places them into suitable directories. Files are placed in /home/kubernetes.
function install-kube-binary-config {
  cd "${KUBE_HOME}"
  local server_binary_tar_urls
  while IFS= read -r url; do
    server_binary_tar_urls+=("$url")
  done < <(split-commas "${SERVER_BINARY_TAR_URL}")
  local -r server_binary_tar="${server_binary_tar_urls[0]##*/}"
  if [[ -n "${SERVER_BINARY_TAR_HASH:-}" ]]; then
    local -r server_binary_tar_hash="${SERVER_BINARY_TAR_HASH}"
  else
    echo "Downloading binary release sha512 (not found in env)"
    download-or-bust "" "${server_binary_tar_urls[@]/.tar.gz/.tar.gz.sha512}"
    local -r server_binary_tar_hash=$(cat "${server_binary_tar}.sha512")
  fi

  if is-preloaded "${server_binary_tar}" "${server_binary_tar_hash}"; then
    echo "${server_binary_tar} is preloaded."
  else
    echo "Downloading binary release tar"
    download-or-bust "${server_binary_tar_hash}" "${server_binary_tar_urls[@]}"
    tar xzf "${KUBE_HOME}/${server_binary_tar}" -C "${KUBE_HOME}" --overwrite
    # Copy docker_tag and image files to ${KUBE_HOME}/kube-docker-files.
    local -r src_dir="${KUBE_HOME}/kubernetes/server/bin"
    local dst_dir="${KUBE_HOME}/kube-docker-files"
    mkdir -p "${dst_dir}"
    cp "${src_dir}/"*.docker_tag "${dst_dir}"
    if [[ "${KUBERNETES_MASTER:-}" == "false" ]]; then
      cp "${src_dir}/kube-proxy.tar" "${dst_dir}"
    else
      cp "${src_dir}/kube-apiserver.tar" "${dst_dir}"
      cp "${src_dir}/kube-controller-manager.tar" "${dst_dir}"
      cp "${src_dir}/kube-scheduler.tar" "${dst_dir}"
      cp -r "${KUBE_HOME}/kubernetes/addons" "${dst_dir}"
    fi
    load-docker-images
    mv "${src_dir}/kubelet" "${KUBE_BIN}"
    mv "${src_dir}/kubectl" "${KUBE_BIN}"

    # Some older images have LICENSES baked-in as a file. Presumably they will
    # have the directory baked-in eventually.
    rm -rf "${KUBE_HOME}"/LICENSES
    mv "${KUBE_HOME}/kubernetes/LICENSES" "${KUBE_HOME}"
    mv "${KUBE_HOME}/kubernetes/kubernetes-src.tar.gz" "${KUBE_HOME}"

    # Pin docker images to avoid GC
    pin-docker-images

    record-preload-info "${server_binary_tar}" "${server_binary_tar_hash}"
  fi

  retag-docker-images

  if [[ "${NETWORK_PROVIDER:-}" == "kubenet" ]] || \
     [[ "${NETWORK_PROVIDER:-}" == "cni" ]]; then
    install-cni-binaries
  fi

  # Put kube-system pods manifests in ${KUBE_HOME}/kube-manifests/.
  install-kube-manifests
  chmod -R 755 "${KUBE_BIN}"

  # Install gci mounter related artifacts to allow mounting storage volumes in GCI
  install-gci-mounter-tools

  # Remount the Flexvolume directory with the "exec" option, if needed.
  if [[ "${REMOUNT_VOLUME_PLUGIN_DIR:-}" == "true" && -n "${VOLUME_PLUGIN_DIR:-}" ]]; then
    remount-flexvolume-directory "${VOLUME_PLUGIN_DIR}"
  fi

  # Install crictl on each node.
  install-crictl

  # Preload pause image
  preload-pause-image

  # Copy health check binaries to a tmpfs mount to reduce block IO usage.
  setup-shm-healthcheck-binaries

  # TODO(awly): include the binary and license in the OS image.
  install-exec-auth-plugin

  if [[ "${KUBERNETES_MASTER:-}" == "false" ]] && \
     [[ "${ENABLE_NODE_PROBLEM_DETECTOR:-}" == "standalone" ]]; then
    install-node-problem-detector
    install-npd-custom-plugins
  fi

  # Clean up.
  rm -rf "${KUBE_HOME}/kubernetes"
  rm -f "${KUBE_HOME}/${server_binary_tar}"
  rm -f "${KUBE_HOME}/${server_binary_tar}.sha512"
}

function setup-shm-healthcheck-binaries() {
  if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
    return
  fi
  if [[ "${ENABLE_SHM_HEALTHCHECK_BINARIES:-}" != "true" ]];then
    return
  fi

  local -r shm_dir="${HEALTHCHECK_SHM_DIR:-/dev/kube_shm}"
  local -r shm_bin_dir="${shm_dir}/bin"

  mkdir -p "$shm_dir"
  mount -t tmpfs -o exec none "$shm_dir"
  mkdir "${shm_bin_dir}"

  cp -f "${KUBE_BIN}/crictl" "${shm_bin_dir}/crictl"
  cp -f "$(which curl)" "${shm_bin_dir}/curl"
}

function configure-pga-if-needed() {
  echo "Detecting connectivity to ${STORAGE_ENDPOINT}..."
  local status=0
  curl --ipv4 -L --connect-timeout 10 --retry 3  --retry-connrefused ${STORAGE_ENDPOINT} || status="$?"
  # connection is refused(7) or timeout(28).
  if [[ "${status}" == "7" || "${status}" == "28" ]]; then
    status=0
    local pga_ip
    pga_ip=`curl ${PGA_ENDPOINT} -w '%{remote_ip}' --connect-timeout 10 -s -o /dev/null` || status="$?"
    registry_domain="$(echo "${KUBE_DOCKER_REGISTRY}" | cut -d '/' -f 1)"
    if [[ "${status}" == "0" ]]; then
      echo "Configure /etc/hosts to use private google access"
      echo "$pga_ip ${STORAGE_ENDPOINT#https://}" >> /etc/hosts
      echo "$pga_ip ${registry_domain}" >> /etc/hosts
      # continue pga support for domain gke.gcr.io
      echo "$pga_ip gke.gcr.io" >> /etc/hosts
    fi
  fi
}

# This function detects the platform/arch of the machine where the script runs,
# and sets the HOST_PLATFORM and HOST_ARCH environment variables accordingly.
# Callers can specify HOST_PLATFORM_OVERRIDE and HOST_ARCH_OVERRIDE to skip the detection.
# This function is adapted from the detect_client_info function in cluster/get-kube-binaries.sh
# and kube::util::host_os, kube::util::host_arch functions in hack/lib/util.sh
# This function should be synced with detect_host_info in ./configure-helper.sh
function detect_host_info() {
  HOST_PLATFORM=${HOST_PLATFORM_OVERRIDE:-"$(uname -s)"}
  case "${HOST_PLATFORM}" in
    Linux|linux)
      HOST_PLATFORM="linux"
      ;;
    *)
      echo "Unknown, unsupported platform: ${HOST_PLATFORM}." >&2
      echo "Supported platform(s): linux." >&2
      echo "Bailing out." >&2
      exit 2
  esac

  HOST_ARCH=${HOST_ARCH_OVERRIDE:-"$(uname -m)"}
  case "${HOST_ARCH}" in
    x86_64*|i?86_64*|amd64*)
      HOST_ARCH="amd64"
      ;;
    aHOST_arch64*|aarch64*|arm64*)
      HOST_ARCH="arm64"
      ;;
    *)
      echo "Unknown, unsupported architecture (${HOST_ARCH})." >&2
      echo "Supported architecture(s): amd64 and arm64." >&2
      echo "Bailing out." >&2
      exit 2
      ;;
  esac
}

# Retries a command forever with a delay between retries.
# Args:
#  $1    : delay between retries, in seconds.
#  $2... : the command to run.
function retry-forever {
  local -r delay="$1"
  shift 1

  until "$@"; do
    echo "== $* failed, retrying after ${delay}s"
    sleep "${delay}"
  done
}

# Initializes variables used by the log-* functions.
#
# get-metadata-value must be defined before calling this function.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-init {
  # Used by log-* functions.
  LOG_CLUSTER_ID=${LOG_CLUSTER_ID:-$(get-metadata-value 'instance/attributes/cluster-uid' 'get-metadata-value-error')}
  LOG_INSTANCE_NAME=$(hostname || echo 'hostname-error')
  LOG_BOOT_ID=$(journalctl --list-boots | grep -E '^ *0' | awk '{print $2}' || echo 'journalctl-error')
  declare -Ag LOG_START_TIMES
  declare -ag LOG_TRAP_STACK

  LOG_STATUS_STARTED='STARTED'
  LOG_STATUS_COMPLETED='COMPLETED'
  LOG_STATUS_ERROR='ERROR'
}

# Sets an EXIT trap.
# Args:
#   $1:... : the trap command.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-trap-push {
  local t="${*:1}"
  LOG_TRAP_STACK+=("${t}")
  # shellcheck disable=2064
  trap "${t}" EXIT
}

# Removes and restores an EXIT trap.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-trap-pop {
  # Remove current trap.
  unset 'LOG_TRAP_STACK[-1]'

  # Restore previous trap.
  if [ ${#LOG_TRAP_STACK[@]} -ne 0 ]; then
    local t="${LOG_TRAP_STACK[-1]}"
    # shellcheck disable=2064
    trap "${t}" EXIT
  else
    # If no traps in stack, clear.
    trap EXIT
  fi
}

# Logs the end of a bootstrap step that errored.
# Args:
#  $1 : bootstrap step name.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-error {
  local bootstep="$1"

  log-proto "${bootstep}" "${LOG_STATUS_ERROR}" "encountered non-zero exit code"
}

# Wraps a command with bootstrap logging.
# Args:
#   $1    : bootstrap step name.
#   $2... : the command to run.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-wrap {
  local bootstep="$1"
  local command="${*:2}"

  log-trap-push "log-error ${bootstep}"
  log-proto "${bootstep}" "${LOG_STATUS_STARTED}"
  $command
  log-proto "${bootstep}" "${LOG_STATUS_COMPLETED}"
  log-trap-pop
}

# Logs a bootstrap step start. Prefer log-wrap.
# Args:
#   $1 : bootstrap step name.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-start {
  local bootstep="$1"

  log-trap-push "log-error ${bootstep}"
  log-proto "${bootstep}" "${LOG_STATUS_STARTED}"
}

# Logs a bootstrap step end. Prefer log-wrap.
# Args:
#   $1 : bootstrap step name.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-end {
  local bootstep="$1"

  log-proto "${bootstep}" "${LOG_STATUS_COMPLETED}"
  log-trap-pop
}

# Writes a log proto to stdout.
# Args:
#   $1: bootstrap step name.
#   $2: status. Either 'STARTED', 'COMPLETED', or 'ERROR'.
#   $3: optional status reason.
#
# NOTE: this function is duplicated in configure-helper.sh, any changes here
# should be duplicated there as well.
function log-proto {
  local bootstep="$1"
  local status="$2"
  local status_reason="${3:-}"

  # Get current time.
  local current_time
  current_time="$(date --utc '+%s.%N')"
  # ...formatted as UTC RFC 3339.
  local timestamp
  timestamp="$(date --utc --date="@${current_time}" '+%FT%T.%NZ')"

  # Calculate latency.
  local latency='null'
  if [ "${status}" == "${LOG_STATUS_STARTED}" ]; then
    LOG_START_TIMES["${bootstep}"]="${current_time}"
  else
    local start_time="${LOG_START_TIMES["${bootstep}"]}"
    unset 'LOG_START_TIMES['"${bootstep}"']'

    # Bash cannot do non-integer math, shell out to awk.
    latency="$(echo "${current_time} ${start_time}" | awk '{print $1 - $2}')s"

    # The default latency is null which cannot be wrapped as a string so we must
    # do it here instead of the printf.
    latency="\"${latency}\""
  fi

  printf '[cloud.kubernetes.monitoring.proto.SerialportLog] {"cluster_hash":"%s","vm_instance_name":"%s","boot_id":"%s","timestamp":"%s","bootstrap_status":{"step_name":"%s","status":"%s","status_reason":"%s","latency":%s}}\n' \
  "${LOG_CLUSTER_ID}" "${LOG_INSTANCE_NAME}" "${LOG_BOOT_ID}" "${timestamp}" "${bootstep}" "${status}" "${status_reason}" "${latency}"
}

# Prelaod components for both - preloader and runtime
# Variables needed for this function to work will be set by the preloader
function preload {
  cd "${KUBE_HOME}"
  if [[ "${ENABLE_AUTH_PROVIDER_GCP:-""}" == "true" ]]; then
    log-wrap 'InstallExternalCredentialProvider' install-auth-provider-gcp
  fi

  if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
    log-wrap 'InstallHurl' install-hurl
  fi

  if [[ "${KUBERNETES_MASTER:-}" == "true" && -n "${K8S_PKI_GCS_PATH:-}" ]]; then
    log-wrap "InstallK8sPki" install-k8s-pki
  fi

  if [[ "${KUBERNETES_MASTER:-}" != "true" && -n "${GVISOR_INSTALLER_IMAGE_HASH:-}" ]]; then
    log-wrap 'DownloadGvisorInstaller' download-gvisor-installer "${GVISOR_INSTALLER_IMAGE_HASH}"
  fi
}

######### Main Function ##########
log-init
detect_host_info

# Preloader will source this script, and skip the main function. The preloader
# will choose what to preload by calling install-X functions directly.
# When configure.sh is sourced by the preload script, $0 and $BASH_SOURCE are
# different. $BASH_SOURCE still contains the path of configure.sh, while $0 is
# the path of the preload script.
if [[ "$0" != "$BASH_SOURCE" && "${IS_PRELOADER:-"false"}" == "true" ]]; then
  # preload common components
  preload
  echo "Running in preloader instead of VM bootsrapping. Skipping installation steps as preloader script will source configure.sh and call all non-common functions."
  return
fi

log-start 'ConfigureMain'
echo "Start to install kubernetes files"

# if install fails, message-of-the-day (motd) will warn at login shell
log-wrap 'SetBrokenMotd' set-broken-motd

KUBE_HOME="/home/kubernetes"
KUBE_BIN="${KUBE_HOME}/bin"

if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
  if [[ "${IS_PRELOADER:-}" != "true" ]] &&\
     grep -qs "PRELOADED," "${KUBE_HOME}/preload_info" &&\
     [[ $(get-metadata-value "instance/attributes/fail-on-artifact-mismatch" "false") == "true" ]]; then
       # Disallow artifact downloads when:
       # - running on master VMs
       # - && not in preloader (running in bootstrap)
       # - && VM image is preloaded
       # - && failure on artifact mismatch feature is enabled
       ARTIFACT_DOWNLOAD_RESTRICTED="true"
  fi

  log-wrap 'InstallHurl' install-hurl
fi

# download and source kube-env
log-wrap 'DownloadKubeEnv' download-kube-env
log-wrap 'SourceKubeEnv' source "${KUBE_HOME}/kube-env"

if [[ "${CONFIGURE_PGA}" == "true" ]]; then
  configure-pga-if-needed
fi

log-wrap 'ConfigureCgroupMode' configure-cgroup-mode

log-wrap 'BestEffortRebootDetection' detect-reboot-needed

log-wrap 'DownloadKubeletConfig' download-kubelet-config "${KUBE_HOME}/kubelet-config.yaml"

if [[ "${KUBERNETES_MASTER:-}" == "true" ]]; then
  log-wrap 'DownloadKubeMasterCerts' download-kube-master-certs-hurl
fi

if docker-installed; then
  # We still need to configure docker so it wouldn't reserver the 172.17.0/16 subnet
  # And if somebody will start docker to build or pull something, logging will also be set up
  log-wrap 'AssembleDockerFlags' assemble-docker-flags
fi

# preload common components
preload

# ensure chosen container runtime is present
log-wrap 'EnsureContainerRuntime' ensure-container-runtime

# binaries and kube-system manifests
log-wrap 'InstallKubeBinaryConfig' install-kube-binary-config

# install Riptide components on non-Ubuntu nodes
if ! is-ubuntu && [[ "${KUBERNETES_MASTER:-}" != "true" ]]; then
  log-wrap 'InstallRiptide' install-riptide
fi

echo "Done for installing kubernetes files"
log-end 'ConfigureMain'


(
(
  set +e



  echo "downloading castai-node-logs-sender binary from https://storage.googleapis.com/castai-node-components/castai-node-logs-sender/releases/0.12.0/castai-node-logs-sender-linux-amd64.tar.gz" >> logs_sender_download_output.log
  curl --fail --silent --show-error --max-time 120 --retry 3 --retry-delay 5 --retry-connrefused https://storage.googleapis.com/castai-node-components/castai-node-logs-sender/releases/0.12.0/castai-node-logs-sender-linux-amd64.tar.gz -o castai-node-logs-sender-linux-amd64.tar.gz 2>> logs_sender_download_output.log
  DOWNLOAD_ERROR=$?

  if [ $DOWNLOAD_ERROR -eq 0 ]; then
    echo "downloading castai-node-logs-sender succeeded" >> logs_sender_download_output.log
    echo "c8941537cdba875abd5bfabefc3878d3fd9cfc7b2b665161bd348e2f846c2619 castai-node-logs-sender-linux-amd64.tar.gz" | sha256sum --check --status 2>> logs_sender_download_output.log
  else
    echo "downloading castai-node-logs-sender failed with error $DOWNLOAD_ERROR" >> logs_sender_download_output.log
  fi

  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
  PREPEND_STRING="{\"logEvents\":[{\"level\": \"info\",\"time\":\"$TIMESTAMP\",\"message\":\""
  CONTENT_STRING=$(awk 1 ORS='\\n' logs_sender_download_output.log)
  APPEND_STRING="\"}]}"

  printf "%s%s%s" "$PREPEND_STRING" "$CONTENT_STRING" "$APPEND_STRING" > logs_sender_download_output.json

  curl --fail --silent --show-error --max-time 120 --retry 3 --retry-delay 5 --retry-connrefused -X POST "https://api.cast.ai/v1/kubernetes/external-clusters/f14c3075-7dc5-4079-9f6d-e7978dd9e52c/nodes/54ebec64-26e2-4645-ba44-45b176123d50/logs" -H "X-Api-Key: eb701bf9477ff08721cd95b84f196e69b1437bc6092c0ed0575b1bfde095e2e6" --data-binary "$(cat logs_sender_download_output.json)" 2> /dev/null
)

mkdir -p bin
BIN_PATH=$PWD/bin/castai-node-logs-sender
tar -xvzf castai-node-logs-sender-linux-amd64.tar.gz
rm castai-node-logs-sender-linux-amd64.tar.gz
mv castai-node-logs-sender $BIN_PATH
chmod +x $BIN_PATH

CONF_PATH=/etc/systemd/system/castai-node-logs-sender.conf

# Proxy vars (if present) below don't have prefix since we want http libraries to pick them automatically in the binary.
cat >${CONF_PATH} <<EOL
CASTAI_API_URL="https://api.cast.ai"
CASTAI_API_KEY="eb701bf9477ff08721cd95b84f196e69b1437bc6092c0ed0575b1bfde095e2e6"
CASTAI_CLUSTER_ID="f14c3075-7dc5-4079-9f6d-e7978dd9e52c"
CASTAI_NODE_ID="54ebec64-26e2-4645-ba44-45b176123d50"
CASTAI_PROVIDER="gke"

EOL

echo "# Creating castai-node-logs-sender systemd service"

cat >/etc/systemd/system/castai-node-logs-sender.service <<EOL
[Unit]
Description=CAST.AI service to send node init logs for troubleshooting.
After=network.target

[Service]
Type=simple
EnvironmentFile=${CONF_PATH}
ExecStart=${BIN_PATH}
RemainAfterExit=false
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOL

echo "# Starting castai-node-logs-sender service..."

systemctl --now enable castai-node-logs-sender
) &


echo "# Overriding kubelet certificate directory mount"
sed -i 's, echo "Mounting /var/lib/kubelet/pki on tmpfs",#&,' /home/kubernetes/bin/configure-helper.sh
sed -i 's, mount -t tmpfs tmpfs /var/lib/kubelet/pki,#&,' /home/kubernetes/bin/configure-helper.sh
