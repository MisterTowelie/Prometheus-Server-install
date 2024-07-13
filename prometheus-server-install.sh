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

# Detected architecture 
case $(uname -m) in
  x86_64)
    readonly PROMETHEUS_ARCH=linux-amd64
    echo -e "$INFO Detected amd64 architecture."
    ;;
  armv7l)
    readonly PROMETHEUS_ARCH=linux-armv7
    echo -e "$INFO Detected ARMv7 architecture."
    ;;
  aarch64)
    readonly PROMETHEUS_ARCH=linux-arm64
    echo -e "$INFO Detected ARMv8 architecture."
    ;;
  *) 
    echo "$ERROR This is unsupported platform, sorry."
    exit 1
    ;;
esac

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
	# readonly PATH_WGET="/usr/bin/wget"
  readonly PATH_CURL="/usr/bin/curl"
  IS_PROMETHEUS="0"
  IS_CURL="0"
  # IS_WGET="0"
}

# Dependencies
function check_Dependencies(){
  PROMETHEUS_REMOTE_VERSION_DOWNLOAD="$(curl -sL "$PROMETHEUS_LATEST_URL" | grep "tag_name" | head -1 | cut -d \" -f 4 | tr -d "v")"
  PROMETHEUS_TAR="prometheus-${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}.${PROMETHEUS_ARCH}.tar.gz"
  PROMETHEUS_DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/""v${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}/${PROMETHEUS_TAR}"
  
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

  readonly PROMETHEUS_REMOTE_VERSION_DOWNLOAD
  readonly PROMETHEUS_TAR
  readonly PROMETHEUS_DOWNLOAD_URL
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
  echo -e "$INFO Download Prometheus Server"
  cd /tmp || exit 1
  if [ -f "${PROMETHEUS_TAR}" ]; then
    echo -e "$INFO Files:${PROMETHEUS_TAR} -$GREEN [found] $NORM"
  else
    echo -e "$INFO Files:${PROMETHEUS_TAR} not found, download now..."
    # { wget --no-check-certificate -c -t3 -T60 -O "$PROMETHEUS_TAR" "${PROMETHEUS_DOWNLOAD_URL}" || curl --request GET -sL --url "${PROMETHEUS_DOWNLOAD_URL}" --output "$PROMETHEUS_TAR" ; }
    if ! curl --request GET -sL --url "${PROMETHEUS_DOWNLOAD_URL}" --output "$PROMETHEUS_TAR"; then
      echo -e "$ERROR Download ${PROMETHEUS_TAR} $RED failed. $NORM"
      rm -Rf "$PROMETHEUS_TAR"
    fi
  fi
}

# Unpack archive
function unpack_Archive(){
  if ! tar xfz "${PROMETHEUS_TAR}"; then
    echo -e "$ERROR An error occurred while unzipping the$RED${PROMETHEUS_TAR}$NORM"
    rm -Rf "$PROMETHEUS_TAR"
  else
    cd prometheus-"${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}"."${PROMETHEUS_ARCH}" || exit 1
  fi

}

# Make prometheus user
function check_Users(){
  if grep -qs "^prometheus:" /etc/passwd > /dev/null; then
    echo -e "$INFO User Prometheus -$GREEN [found]$NORM"
  else
    adduser --no-create-home --disabled-login --shell /bin/false --gecos "Prometheus Monitoring User" prometheus
  fi
}

# Make directories and dummy files necessary for prometheus
function create_Directory(){
  check_Users
  [ ! -d "${PROMETHEUS_FOLDER_CONFIG}" ] && mkdir -p "${PROMETHEUS_FOLDER_CONFIG}"
  [ ! -d "${PROMETHEUS_FOLDER_TSDATA}" ] && mkdir -p "${PROMETHEUS_FOLDER_TSDATA}"
}

function create_Service(){
  echo -e "$INFO Configuring Prometheus..."
  cat > "/etc/systemd/system/prometheus.service"<<-EOF
[Unit]
Description=Prometheus Server
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
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
   cp -f "prometheus" "promtool" "${PROMETHEUS_FOLDER_BASE_DIR}" &&
   cp -n "prometheus.yml" "${PROMETHEUS_FOLDER_CONFIG}" &&
   cp -Rf "consoles/" "console_libraries/" "${PROMETHEUS_FOLDER_CONFIG}" &&
   chmod u+x "${PROMETHEUS_FOLDER_BASE_DIR}/prometheus" &&
   chmod u+x "${PROMETHEUS_FOLDER_BASE_DIR}/promtool" &&
   chown prometheus:prometheus $PROMETHEUS_FOLDER_BASE_DIR/prometheus &&
   chown prometheus:prometheus $PROMETHEUS_FOLDER_BASE_DIR/promtool &&
   chown -Rv prometheus:prometheus $PROMETHEUS_FOLDER_CONFIG
}

# Installation cleanup
function cleanup_Install(){
  rm -Rf /tmp/prometheus-"${PROMETHEUS_REMOTE_VERSION_DOWNLOAD}"*
}

# Start prometheus Service
function service_Prometheus(){
   systemctl daemon-reload &&
   systemctl enable prometheus &&
   systemctl start prometheus &&
   systemctl status prometheus --no-pager
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
		apt update &&
		apt install -y wget curl
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
  completion_Message
  cleanup_Install
}

main
