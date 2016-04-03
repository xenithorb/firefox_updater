#!/bin/bash
#
# Cron script to update Mozilla Firefox build editions
# Targeted OS: Fedora 23 - will probably work on most
# Default Firefox version: Firefox Developer Edition (aurora)
# Leaves files in the following spots:
#	/opt/firefox-dev
#	/usr/share/applications/firefox-dev.desktop
#
 set -x
# INSTALL_DIR is assumed to not be changed in the below base64 block
# (the .desktop file) Will require you to pipe that through
# `base64 -d | gunzip > file` if you want to change that
INSTALL_DIR="/opt/firefox-dev"
SCRIPT_LOC="$(readlink -e $0)"
SCRIPT_DIR="${SCRIPT_LOC%/*}"
ARCH="linux64"
LANG="en-US"
PRODUCT="firefox-aurora-latest-ssl"
LATEST_TAR_URL="https://download.mozilla.org/?product=${PRODUCT}&os=${ARCH}&lang=${LANG}"
TEMPFILE="$(mktemp -t firefox-dev.XXXX)"
XDG_APPS="/usr/share/applications"
MOZ_PROFILE_PATH="$HOME/.mozilla/firefox"
APPLICATION_FILE="${INSTALL_DIR}/firefox-dev.desktop"

chcon_firefox() {
        sudo chcon -u system_u -r object_r "$@"
}

get_default_profile() {
	while IFS='=' read -r var val; do
		if [[ "$var" == \[*\] ]]; then
			section=$( a=${var/[}; a=${a/]}; echo $a )
			section_a+=($section)
		elif [[ $val ]]; then
			declare -A "${section}[${var}]=${val}"
		fi
	done < "${1}"
	for i in "${section_a[@]}"; do
		if [[ "$(eval echo \${$i[Default]})" == 1 ]]; then
			eval echo "\${$i[Path]}"
		fi
	done
}

wrap_pref() {
	echo "user_pref(\"$1\", $2);"
}

jinja_replace() {
	# $1 = template variable, i.e. {{SCRIPT_LOC}} 
	# $2 = value to replace with
	# $3 = file to edit
	[[ -f "$3" ]] && { INLINE="-i"; SUDO="sudo"; }
	"$SUDO" sed -r "$INLINE" 's|\{\{[ ]*'"$1"'[ ]*\}\}|'"$2"'|g' "$3"
}

wget --quiet -O "${TEMPFILE}" "${LATEST_TAR_URL}" &&
if [[ ! -d ${INSTALL_DIR} ]]; then
	sudo mkdir -p "${INSTALL_DIR}"
else
	sudo find "${INSTALL_DIR:?ERROR DIR NULL}" -mindepth 1 -delete
fi
sudo tar --strip-components=1 -C "${INSTALL_DIR}" -xf "${TEMPFILE}"
rm -f "${TEMPFILE}"
# Set selinux contexts modeled after Fedora's firefox package
if [[ selinuxenabled ]]; then
	chcon_firefox -t lib_t                  "${INSTALL_DIR}/" -R
	chcon_firefox -t mozilla_exec_t         "${INSTALL_DIR}/"firefox{,-bin}
	chcon_firefox -t mozilla_plugin_exec_t  "${INSTALL_DIR}/plugin-container"
	chcon_firefox -t bin_t                  "${INSTALL_DIR}/run-mozilla.sh"
fi

# Check for firefox-dev.desktop file
if [[ ! -f ${APPLICATION_FILE} ]]; then
	sudo cp "${0%/*}/firefox-dev.desktop" "${APPLICATION_FILE}"
	# Let's deposit the real file into /opt/firefox-dev/ and link to it
	# so that if the user just removes the /opt dir, and forgets the link
	# it doesn't point to anything
	if [[ ! -L "${XDG_APPS}/${APPLICATION_FILE##*/}" ]]; then
		sudo ln -sf "${APPLICATION_FILE}" "${XDG_APPS}/"
	fi
fi

if [[ -d ${MOZ_PROFILE_PATH} ]]; then
	DEFAULT_PROFILE="${MOZ_PROFILE_PATH}/$(get_default_profile "${MOZ_PROFILE_PATH}/profiles.ini")"
	DEFAULT_PROFILE_PREFS="${DEFAULT_PROFILE}/prefs.js"
	pref_a=("app.update.enabled" "app.update.auto")
	pids="$(pidof firefox)"
	
	if [[ -f "${DEFAULT_PROFILE_PREFS}" ]]; then
		for i in "${pref_a[@]}"; do
			line="$(wrap_pref "$i" "false")"
			if ! grep -q "$line" "${DEFAULT_PROFILE_PREFS}"; then
				# Firefox re-writes prefs.js when closed
				# So we close it first, then write
				kill -TERM "$pids"
				echo "$line" >> "${DEFAULT_PROFILE_PREFS}"
			fi
		done
	fi
fi

# Copy systemd service and timer 
sudo cp -r "${SCRIPT_DIR}/systemd" "${INSTALL_DIR}/"
jinja_replace "SCRIPT_LOC" "$SCRIPT_LOC" "${INSTALL_DIR}/systemd/firefox-updater.service"
sudo systemctl link "${INSTALL_DIR}/systemd/firefox-updater.service"
sudo systemctl --now enable "${INSTALL_DIR}/systemd/firefox-updater.timer"
