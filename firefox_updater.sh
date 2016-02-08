#!/bin/bash
#
# Cron script to update Mozilla Firefox build editions 
# Targeted OS: Fedora 23
# Default Firefox version: Firefox Developer Edition (aurora)
 set -x
OPT_INSTALL_DIR="/opt/firefox-dev"
ARCH="linux64"
LANG="en-US"
PRODUCT="firefox-aurora-latest-ssl"
LATEST_TAR_URL="https://download.mozilla.org/?product=${PRODUCT}&os=${ARCH}&lang=${LANG}"
TEMPFILE="$(mktemp -t firefox-dev.XXXX)"

chcon_firefox() {
        sudo chcon -u system_u -r object_r "$@"
}

wget -O "${TEMPFILE}" "${LATEST_TAR_URL}" &&

if [[ ! -d ${OPT_INSTALL_DIR} ]]; then
	sudo mkdir -p "${OPT_INSTALL_DIR}"
else
	sudo find "${OPT_INSTALL_DIR:?ERROR DIR NULL}" -mindepth 1 -delete
fi

sudo tar --strip-components=1 -C "${OPT_INSTALL_DIR}" -xf "${TEMPFILE}"
rm -f "${TEMPFILE}"

# Set selinux contexts modeled after Fedora's firefox package 
chcon_firefox -t lib_t                  "${OPT_INSTALL_DIR}/" -R
chcon_firefox -t mozilla_exec_t         "${OPT_INSTALL_DIR}/"firefox{,-bin}
chcon_firefox -t mozilla_plugin_exec_t  "${OPT_INSTALL_DIR}/plugin-container"
chcon_firefox -t bin_t                  "${OPT_INSTALL_DIR}/run-mozilla.sh"

# Check for firefox-dev.desktop file 
APPLICATION_FILE="/usr/share/applications/firefox-dev.desktop"
if [[ ! -f ${APPLICATION_FILE} ]]; then
	cat <<-EOF | base64 -d | sudo sh -c "gunzip -c > \"${APPLICATION_FILE}\""
	H4sIAEDluFYAA41Vz28bRRS+718xF05o7TYnJGsPKU1RhAgRqTBSZFVj77N36tmZ1cys7eRE0jat
	FFcIJIoKqkSkUpOKqIQfFQjoZdv/Yd0cfQHZfwRv19511kkKB9tP733z3jfvfX6zeRV028iArAij
	tmrWx6A0k8K5XLpkrVEfnGtMQVP2yFXoAJcBKLLiMoMQ6z0QoFgjRVWhTq4o2dWgTvs3G7TmrNEO
	tKgrFelCvRjVteSk7ER/kUBJj0dHr17Ay/sFEOg3pWhigeGd+Hh4Lz5+/Sw+JvHgpD/ci5+iC79P
	+kU0w4LVqq2BUyaKIZWWYS1qIFSkulDHC1Oq9ei5aEWHevvV54UwMzVndv8zR28ixdHuk9HuYHTr
	wejWH+n3Yep5XgC2Zc2ZfPM7Gf/WHz/6c/L1j5NvPy0ARB05gjEcFvss+JTeOSMQIj9EFyLyonQB
	pltX29DiL++4VLUpwa4VEeb0VBavHJgbVz56E0C3a86qMKAEmNn4weOMunRh+rozvRiPHiN9sN6V
	vg/CzJpNjAdp7pl7rrcQQpKIFXgqmTyuk4tlShPREdFGRQcC2qQqFXdJlblpxjA/4gJS9UnGluhQ
	NUHk4VyeIZAAb8ppoWCiz/jX4U58FA/ipyT+Jf7+9eHwLol/GN6NB8O9k/6CYkl8HA9IJmky3EMT
	ASf9+Nk8Kcp4AyVMc1ZMkFTXrBPepHNcpmnkhrRzdA5IVL1MOoxHBy0vOuDRzyRXOH7ydqf6XtEB
	l4oSVmxpUd67X/zz4Ke/nwxGO1+Ndl6Mdh7muJm6J49uk/Fn/cmX+LP/eLz/cLx/D40clmh8A1tM
	gug7glzNKbqJynFBtUEQDyfBFq+TSP3Cs/LiWFHugkGiCpm2lMxBZj5oQc/28rTmL4Akql/PhJ6U
	yW4wV1ui94QmTXlin+uotZUeNJyyDEy5Od3GtgudzCZvhdZqA1f2GcBsG5QZRnXZl9uJcXnpnVIg
	WtZ1UD4TlDtNynHQ17cCcJaDgLMGTbf7B8yH1GmgZ8qe8XkltXpo0Dmu3EtCby96O8ItJQU5p6Ve
	OI2nx300erZueOCD7VHhciToGROc79UVa8NQZcJgTRrW3HKMClGVuKNbUjHQyf7qStWu4F92tn8r
	1vuwhT5XO9i+yqwJlazVFWu5kVDUjoCu3WXCld1KYgaKdTBv5rKsT+zZ22hfYxzsVaEN5dzOXshL
	paUly9rM3s9pVjJPWpu+nx8GqFZK1qCLuyXx//c0z01apHc2+fo0/v+K2Avp0qr/Aq7c23ULCAAA
	EOF
fi
