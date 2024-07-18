#!/usr/bin/env bash

############################################################################
# Auto install Prometheus Server on Linux (Amd64 and Arm)
# Tested on Debian11+(Amd64 and Aaarch64), Ubuntu20+(Amd64), Trisquel10+(Amd64)
# Copyright (c) 2024 MisterTowelie Released under the GNU GPLv3 license .
# https://github.com/MisterTowelie/Prometheus-Server-install
############################################################################

############################################################################
#   VERSION HISTORY   ######################################################
############################################################################
# v1.0.0
# - Initial version.
############################################################################
# v1.0.1
# - Code correction.
############################################################################

# Troubleshooting
#set -e -u -x

# Define Colors
readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[0;33m"
readonly BOLD="\033[1m"
readonly NORM="\033[0m"
readonly INFO="${BOLD}${GREEN}[INFO]:$NORM"
readonly ERROR="${BOLD}${RED}[ERROR]:$NORM"
readonly WARNING="${BOLD}${YELLOW}[WARNING]:$NORM"

# Root only
[[ $EUID -ne 0 ]] && echo -e "$WARNING This script must be run as root!" && exit 1

# Detected architecture, platform (test)
if [[ "$(uname)" != 'Linux' ]]; then
  echo -e "$ERROR This operating system is not supported."
  exit 1
fi
case $(uname -m) in
  'i386' | 'i686')
    MACHINE_ARCH='linux-386'
    echo -e "$INFO Detected i386(i686) architecture."
    ;;
  'amd64' | 'x86_64')
    MACHINE_ARCH='linux-amd64'
    echo -e "$INFO Detected Amd64 architecture."
    ;;
  'armv5tel')
    MACHINE_ARCH='linux-armv5'
    echo -e "$INFO Detected ARMv5tel architecture."
    ;;
  'armv6l')
    MACHINE_ARCH='linux-armv6'
    grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE_ARCH='linux-armv5'
    echo -e "$INFO Detected ARMv6 architecture."
    ;;
  'armv7' | 'armv7l')
    MACHINE_ARCH='linux-armv7'
    echo -e "$INFO Detected ARMv7 architecture."
    ;;
  'armv8' | 'aarch64')
    MACHINE_ARCH='linux-arm64'
    echo -e "$INFO Detected ARMv8 architecture."
    ;;
  'mips')
    MACHINE_ARCH='linux-mips'
    echo -e "$INFO Detected Mips architecture."
    ;;
  'mipsle')
    MACHINE_ARCH='linux-mipsle'
    echo -e "$INFO Detected Mipsle architecture."
    ;;
  'mips64')
    MACHINE_ARCH='linux-mips64'
    lscpu | grep -q "Little Endian" && MACHINE_ARCH='linux-mips64le'
    echo -e "$INFO Detected Mips64 architecture."
    ;;
  'mips64le')
    MACHINE_ARCH='linux-mips64le'
    echo -e "$INFO Detected Mips64le architecture."
    ;;
  'ppc64')
    MACHINE_ARCH='linux-ppc64'
    echo -e "$INFO Detected Ppc64 architecture."
    ;;
  'ppc64le')
    MACHINE_ARCH='linux-ppc64le'
    echo -e "$INFO Detected Ppc64le architecture."
    ;;
  'riscv64')
    MACHINE_ARCH='linux-riscv64'
    echo -e "$INFO Detected Riscv64 architecture."
    ;;
  's390x')
    MACHINE_ARCH='linux-s390x'
    echo -e "$INFO Detected s390x architecture."
    ;;
  *) 
    echo -e "$ERROR This is unsupported platform, sorry."
    exit 1
    ;;
esac
if [[ ! -f '/etc/os-release' ]]; then
  echo -e "$ERROR Don't use outdated Linux distributions."
  exit 1
fi
if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
    true
  elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
    true
  else
    echo -e "$ERROR Only Linux distributions using systemd are supported."
    exit 1
  fi
  if [[ "$(type -P apt)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
  elif [[ "$(type -P dnf)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
  elif [[ "$(type -P yum)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='yum -y install'
  elif [[ "$(type -P zypper)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
  elif [[ "$(type -P pacman)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='pacman -Syy --noconfirm'
    elif [[ "$(type -P emerge)" ]]; then
    PACKAGE_MANAGEMENT_INSTALL='emerge -qv'
    echo -e "$INFO PACKAGE_MANAGEMENT_INSTALL= $PACKAGE_MANAGEMENT_INSTALL"
  else
    echo -e "$ERROR The script does not support the package manager in this operating system."
    exit 1
  fi

# Dependencies
function set_Dependencies(){
  if [ -f /usr/bin/prometheus ]; then
    readonly PROMETHEUS_FOLDER_BASE_DIR="/usr/bin"
  else
    readonly PROMETHEUS_FOLDER_BASE_DIR="/usr/local/bin"
  fi

  readonly PROMETHEUS_FOLDER_CONFIG="/etc/prometheus"
  readonly PROMETHEUS_FOLDER_TSDATA="/etc/prometheus/data"
  readonly PROMETHEUS_LATEST_URL="https://api.github.com/repos/prometheus/prometheus/releases/latest"
  readonly PATH_PROMETHEUS="${PROMETHEUS_FOLDER_BASE_DIR}/prometheus"
  readonly PATH_PROMTOOL="${PROMETHEUS_FOLDER_BASE_DIR}/promtool"
  readonly PATH_CONFIG="${PROMETHEUS_FOLDER_CONFIG}/prometheus.yml"
  readonly PATH_SERVICE="/etc/systemd/system/prometheus.service"
  readonly SERVICE_USER="prometheus"
	# readonly PATH_WGET="/usr/bin/wget"
  readonly PATH_CURL="/usr/bin/curl"
  IS_PROMETHEUS="0"
  IS_CURL="0"
  # IS_WGET="0"
}

# Dependencies
function check_Dependencies(){
  
	if [ -f $PATH_PROMETHEUS ]; then
		STATUS_PATH_PROMETHEUS="$(echo -e "$GREEN OK $NORM")"
	else
		STATUS_PATH_PROMETHEUS="$(echo -e "$RED NA $NORM")"
		IS_PROMETHEUS="1"
	fi

	if [ -f $PATH_PROMTOOL ]; then
		STATUS_PATH_PROMTOOL="$(echo -e "$GREEN OK $NORM")"
	else
	  STATUS_PATH_PROMTOOL="$(echo -e "$YELLOW NA $NORM")"
	fi

  if [ -f $PATH_CONFIG ]; then
		STATUS_PATH_CONFIG="$(echo -e "$GREEN OK $NORM")"
	else
	  STATUS_PATH_CONFIG="$(echo -e "$YELLOW NA $NORM")"
	fi

  if [ -f $PATH_SERVICE ]; then
		STATUS_PATH_SERVICE="$(echo -e "$GREEN OK $NORM")"
	else
	  STATUS_PATH_SERVICE="$(echo -e "$YELLOW NA $NORM")"
	fi

  if [ -f $PATH_CURL ]; then
	  STATUS_PATH_CURL="$(echo -e "$GREEN OK $NORM")"
	else
		STATUS_PATH_CURL="$(echo -e "$RED NA $NORM")"
		IS_CURL="1"
	fi

  # if [ -f $PATH_WGET ]; then
	# 	STATUS_PATH_WGET="$(echo -e "$GREEN OK $NORM")"
  # else
	#   STATUS_PATH_WGET="$(echo -e "$RED NA $NORM")"
	#   IS_WGET="1"
  # fi

  local PROMETHEUS_LOCAL_COMMIT
  local PROMETHEUS_REMOTE_COMMIT
}

# Show Dependencies
function show_Dependencies(){
	echo ""
	echo "List of File Dependencies"
	echo ""
	echo -e "$INFO $PATH_PROMETHEUS - $GREEN Status:$NORM $STATUS_PATH_PROMETHEUS"
	echo -e "$INFO $PATH_PROMTOOL - $GREEN Status:$NORM $STATUS_PATH_PROMTOOL"
	echo -e "$INFO $PATH_CONFIG - $GREEN Status:$NORM $STATUS_PATH_CONFIG"
  echo -e "$INFO $PATH_SERVICE - $GREEN Status:$NORM $STATUS_PATH_SERVICE"
	echo -e "$INFO $PATH_CURL - $GREEN Status:$NORM $STATUS_PATH_CURL"
	# echo -e "$INFO $PATH_WGET - $GREEN Status:$NORM $STATUS_PATH_WGET"
	echo ""
	read -n1 -r -p "Press ENTER to continue...."
}

# Testing the new version of the Prometheus server
function check_update_Prometheus(){
  echo -e "$INFO Check update Prometheus Server"
  PROMETHEUS_LOCAL_COMMIT="$("${PROMETHEUS_FOLDER_BASE_DIR}/prometheus" --version | grep "version" | head -1 | cut -d : -f 3 | cut -d \) -f 1 | tr -d " ")"
  PROMETHEUS_REMOTE_COMMIT="$(curl -sL "$PROMETHEUS_LATEST_URL" | grep "target_commitish" | head -1 | cut -d \" -f 4 | tr -d " ")"

  if [ "$PROMETHEUS_LOCAL_COMMIT" != "$PROMETHEUS_REMOTE_COMMIT" ]; then
    echo -e "$INFO LOCAL VERSION Prometheus Server is not synced with REMOTE VERSION, initiating update..."
  else
    echo -e "$INFO No new version available for Prometheus Server."
    exit 1
  fi
}

# Download Prometheus Server
function download_Prometheus() {
  PROMETHEUS_REMOTE_VERSION_DOWNLOAD="$(curl -sL "$PROMETHEUS_LATEST_URL" | grep "tag_name" | head -1 | cut -d \" -f 4 | tr -d "v")"
  PROMETHEUS_TAR="prometheus-${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}.${MACHINE_ARCH}.tar.gz"
  PROMETHEUS_DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/""v${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}/${PROMETHEUS_TAR}"
  echo -e "$INFO Download Prometheus Server"
  cd /tmp || exit 1
  if [ -f "${PROMETHEUS_TAR}" ]; then
    echo -e "$INFO Files:${PROMETHEUS_TAR}$GREEN [found]$NORM"
  else
    echo -e "$INFO Files:${PROMETHEUS_TAR}$RED [not found]$NORM, download now..."
    # { wget --no-check-certificate -c -t3 -T60 -O "$PROMETHEUS_TAR" "${PROMETHEUS_DOWNLOAD_URL}" || curl --request GET -sL --url "${PROMETHEUS_DOWNLOAD_URL}" --output "$PROMETHEUS_TAR" ; }
    if ! $(type -P curl) --request GET -sLq --retry 5 --retry-delay 10 --retry-max-time 60 --url "${PROMETHEUS_DOWNLOAD_URL}" --output "$PROMETHEUS_TAR"; then
      echo -e "$ERROR Download ${PROMETHEUS_TAR}$RED [failed].$NORM"
      rm -Rf "$PROMETHEUS_TAR"
    fi
  fi
}

# Unpack archive
function unpack_Archive(){
  if ! tar xfzv "${PROMETHEUS_TAR}"; then
    echo -e "$ERROR An error occurred while unzipping the$RED${PROMETHEUS_TAR}$NORM"
    rm -Rf "$PROMETHEUS_TAR"
    echo -e "$ERROR $$PROMETHEUS_TAR"
    exit 1
  fi
  cd prometheus-"${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}"."${MACHINE_ARCH}" || exit 1
}

# Make prometheus user
function check_Users(){
  if grep -qs "^$SERVICE_USER:" /etc/passwd > /dev/null; then
    echo -e "$INFO User $SERVICE_USER -$GREEN [found]$NORM"
  else
    echo -e "$INFO User $SERVICE_USER -$RED [not found]$NORM/ Create User"
    adduser --no-create-home --disabled-login --shell /bin/false --gecos "Prometheus Monitoring User" $SERVICE_USER
  fi
}

# Make directories and dummy files necessary for prometheus
function create_Directory(){
  check_Users
  mkdir -p "${PROMETHEUS_FOLDER_CONFIG}"
  mkdir -p "${PROMETHEUS_FOLDER_TSDATA}"
}

function create_Service(){
  echo -e "$INFO Configuring Prometheus..."
  cat > "/etc/systemd/system/prometheus.service"<<-EOF
[Unit]
Description=Prometheus Server
Wants=network-online.target
After=network-online.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
Type=simple
Restart=on-failure
ExecStart=$PROMETHEUS_FOLDER_BASE_DIR/prometheus \
    --config.file $PROMETHEUS_FOLDER_CONFIG/prometheus.yml \
    --storage.tsdb.path $PROMETHEUS_FOLDER_TSDATA \
    --web.console.templates=$PROMETHEUS_FOLDER_CONFIG/consoles \
    --web.console.libraries=$PROMETHEUS_FOLDER_CONFIG/console_libraries

[Install]
WantedBy=multi-user.target
EOF
}

# Copy utilities to where they should be in the filesystem
# Assign ownership of the files above to prometheus user
function move_Prometheus(){
   cp -fv "prometheus" "promtool" "${PROMETHEUS_FOLDER_BASE_DIR}" &&
   cp -nv "prometheus.yml" "${PROMETHEUS_FOLDER_CONFIG}" &&
   cp -Rfv "consoles/" "console_libraries/" "${PROMETHEUS_FOLDER_CONFIG}" &&
   chmod u+x "${PROMETHEUS_FOLDER_BASE_DIR}/prometheus" &&
   chmod u+x "${PROMETHEUS_FOLDER_BASE_DIR}/promtool" &&
   chown prometheus:prometheus $PROMETHEUS_FOLDER_BASE_DIR/prometheus &&
   chown prometheus:prometheus $PROMETHEUS_FOLDER_BASE_DIR/promtool &&
   chown -R prometheus:prometheus $PROMETHEUS_FOLDER_CONFIG
}

# Installation cleanup
function cleanup_Install(){
  rm -Rf /tmp/prometheus-"${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}"*
}

# Start Prometheus Service
function service_Prometheus(){
  local PROMETHEUS_CUSTOMIZE
  systemctl daemon-reload &&
  systemctl enable prometheus &&
  systemctl start prometheus
  PROMETHEUS_CUSTOMIZE="$(systemctl list-units | grep 'prometheus' | awk -F ' ' '{print $1}')"
  if systemctl -q is-active "${PROMETHEUS_CUSTOMIZE:-prometheus}"; then
      echo -e "$INFO Start the Prometheus server service."
      completion_Message
  else
      echo -e "$INFO Failed to start Prometheus server service."
      exit 1
  fi
}

# Display a completion message
function completion_Message() {
  echo ""
  echo -e "$INFO Prometheus server setup completed! (possibly successful)"
}

# Install Dependencies
function install_Dependencies() {
  # if [ "${IS_CURL}" == "1" ] || [ "${IS_WGET}" == "1" ]; then
  if [ "${IS_CURL}" == "1" ]; then
		# echo -e "$INFO Installing required packages. Wget and Curl is required to use this installer."
    echo -e "$INFO Installing required packages. Curl is required to use this installer."
		read -n1 -r -p "Press any key to install Curl and continue..."
    if ${PACKAGE_MANAGEMENT_INSTALL} curl; then
      echo -e "$INFO Curl is installed."
    else
      echo -e "$ERROR Installation of Curl failed, please check your network."
      exit 1
    fi
  fi
}

# Prometheus Server Update Block
function update_Prometheus(){
  check_update_Prometheus
  download_Prometheus
  unpack_Archive
  move_Prometheus
}

# Prometheus Server Install Block
function install_Prometheus(){
  download_Prometheus
  unpack_Archive
  create_Directory
  move_Prometheus
  create_Service
}

function main(){
  set_Dependencies
  check_Dependencies
  show_Dependencies
  install_Dependencies
  if [ "${IS_PROMETHEUS}" == "1" ]; then
    install_Prometheus
  else
    update_Prometheus
  fi
  service_Prometheus
  cleanup_Install
}

main
