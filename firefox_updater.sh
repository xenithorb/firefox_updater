#!/bin/bash
#
# Cron script to update Mozilla Firefox build editions 
# Targeted OS: Fedora 23
# Default Firefox version: Firefox Developer Edition (aurora)

OPT_INSTALL_DIR="/opt/firefox-dev"
ARCH="linux64"
LANG="en-US"
PRODUCT="firefox-aurora-latest-ssl"
LATEST_TAR_URL="https://download.mozilla.org/?product=${PRODUCT}&os=${ARCH}&lang=${LANG}"
TEMPFILE="$(mktemp -t firefox-dev.XXXX)"

chcon_firefox() {
        sudo chcon -u system_u -r object_r $@ 
}

wget -O "${TEMPFILE}" "${LATEST_TAR_URL}" &&

if [[ ! -d ${OPT_INSTALL_DIR} ]]; then
	mkdir -p "${OPT_INSTALL_DIR}"
else
	find "${OPT_INSTALL_DIR:?ERROR DIR NULL}" -mindepth 1 -delete
fi

sudo tar --strip-components=1 -C "${OPT_INSTALL_DIR}" -xf "${TEMPFILE}"
rm -f "${TEMPFILE}"

# Set selinux contexts modeled after Fedora's firefox package 
chcon_firefox -t lib_t                  "${OPT_INSTALL_DIR}/" -R
chcon_firefox -t mozilla_exec_t         "${OPT_INSTALL_DIR}/"firefox{,-bin}
chcon_firefox -t mozilla_plugin_exec_t  "${OPT_INSTALL_DIR}/plugin-container"
chcon_firefox -t bin_t                  "${OPT_INSTALL_DIR}/run-mozilla.sh"