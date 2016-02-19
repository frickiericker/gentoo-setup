#!/bin/sh -efux
set -efux
export LANG=C LC_ALL=C
export PATH=/usr/sbin:/usr/bin:/sbin:/bin

HOSTNAME=$(hostname)
HOSTNAME=${HOSTNAME%%.*}

PORTAGE_HOST=xgene
CONFDIR=/root/config
MAKEOPTS='-j 40'

#------------------------------------------------------------------------------
# Entry Point
#------------------------------------------------------------------------------

is_portage_host=$(test ${HOSTNAME} = ${PORTAGE_HOST} && echo y || echo n)

setup_auto() {
    case ${is_portage_host} in
    y)  master ;;
    n)  worker
    esac
}

master() {
    rebuild_kernel
    install_system_configs
    #
    install_portage_configs
    export_shared_portage_tree
    setup_autoupdate_portage_tree
    #
    install_nis_client
    import_home_directory
    install_common_daemons
    install_softwares
    update_world
}

worker() {
    rebuild_kernel
    install_system_configs
    #
    import_shared_portage_tree
    #
    install_nis_client
    import_home_directory
    install_common_daemons
    install_softwares
    update_world
}

#------------------------------------------------------------------------------
# Kernel
#------------------------------------------------------------------------------

rebuild_kernel() {
    # Add custom options to the working kernel
    kernconf='/tmp/kernel.conf'
    zcat /proc/config.gz               |
    cat - "${CONFDIR}/sys/kernel.conf" > "${kernconf}"

    # Make & install
    genkernel --kernel-config="${kernconf}" --makeopts="${MAKEOPTS}" all
}

#------------------------------------------------------------------------------
# Static configs
#------------------------------------------------------------------------------

install_system_configs() {
    install_data -T "${CONFDIR}/etc/fstab.${HOSTNAME}" /etc/fstab
    cat "${CONFDIR}/etc/hosts.common" >> /etc/hosts
}

install_portage_configs() {
    rm -rf /etc/portage/repos.conf   \
           /etc/portage/make.conf    \
           /etc/portage/package.use  \
           /etc/portage/package.mask \
           /etc/portage/package.accept_keywords

    install_data -t /etc/portage               \
                 "${CONFDIR}/etc/repos.conf"   \
                 "${CONFDIR}/etc/make.conf"    \
                 "${CONFDIR}/etc/package.use"  \
                 "${CONFDIR}/etc/package.mask" \
                 "${CONFDIR}/etc/package.accept_keywords"
}

#------------------------------------------------------------------------------
# Share portage tree via NFS
#------------------------------------------------------------------------------

export_shared_portage_tree() {
    emerge -kn net-fs/nfs-utils

    # These directories are requied by nfs
    mkdir -p /var/log/nfs/v4recovery
    mkdir -p /var/log/nfs/rpc_pipefs/nfs

    #
    install_data    "${CONFDIR}/etc/idmapd.conf"         /etc
    install_data -T "${CONFDIR}/etc/exports.${HOSTNAME}" /etc/exports

    #
    systemctl enable nfs-server
}

setup_autoupdate_portage_tree() {
    emerge -kn sys-process/systemd-cron
    install_script "${CONFDIR}/bin/update_portage_tree.sh" /etc/cron.daily
    systemctl enable cron.target
}

import_shared_portage_tree() {
    emerge -kn net-fs/nfs-utils
    mkdir -p /var/log/nfs/rpc_pipefs/nfs

    install_data "${CONFDIR}/etc/idmapd.conf" /etc
    assert fgrep ':/etc/portage' /etc/fstab
    assert fgrep ':/usr/portage' /etc/fstab

    systemctl enable nfs-client.target || true
    systemctl enable remote-fs.target || true
}

#------------------------------------------------------------------------------
# NIS and shared /home
#------------------------------------------------------------------------------

install_nis_client() {
    emerge -kn net-nds/ypbind || {
        # https://bugs.gentoo.org/show_bug.cgi?id=371387
        workdir="/var/tmp/portage/net-nds/yp-tools-2.12-r1/work"
        ypclnt="${workdir}/yp-tools-2.12/src/ypclnt.c"
        sed -i 's|#include <bits/libc-lock.h>||' "${ypclnt}"
        env FEATURES="keepwork" emerge -kn net-nds/ypbind
    }

    domain_confdir='/etc/systemd/system/domainname.service.d'
    install_data -T "${CONFDIR}/etc/domainname.service.conf" \
                    "${domain_confdir}/10-domainname.service.conf"

    install_data "${CONFDIR}/etc/yp.conf"       /etc
    install_data "${CONFDIR}/etc/nsswitch.conf" /etc

    systemctl enable domainname
    systemctl enable ypbind
}

import_home_directory() {
    emerge -kn net-fs/nfs-utils

    assert fgrep ':/home' /etc/fstab

    systemctl enable nfs-client.target || true
    systemctl enable remote-fs.target || true
}

#------------------------------------------------------------------------------
# Common daemons
#------------------------------------------------------------------------------

install_common_daemons() {
    install_ssh_daemon
    install_rsh_daemon
}

install_ssh_daemon() {
    emerge -kn net-misc/openssh
    install_data "${CONFDIR}/etc/sshd_config" /etc/ssh
    systemctl enable sshd
}

install_rsh_daemon() {
    emerge -kn sys-apps/xinetd \
               net-misc/netkit-rsh

    install_data -T "${CONFDIR}/etc/xinetd.rexec"  /etc/xinetd.d/rexec
    install_data -T "${CONFDIR}/etc/xinetd.rlogin" /etc/xinetd.d/rlogin
    install_data -T "${CONFDIR}/etc/xinetd.rsh"    /etc/xinetd.d/rsh

    install_data -T "${CONFDIR}/etc/pam.rexec"  /etc/pam.d/rexec
    install_data -T "${CONFDIR}/etc/pam.rlogin" /etc/pam.d/rlogin
    install_data -T "${CONFDIR}/etc/pam.rsh"    /etc/pam.d/rsh

    systemctl enable xinetd
}

#------------------------------------------------------------------------------
# Required softwares
#------------------------------------------------------------------------------

install_softwares() {
    # System tools
    emerge -kn app-admin/sudo         \
               app-portage/eix        \
               app-portage/gentoolkit \
               net-analyzer/nload     \
               sys-apps/smartmontools \
               sys-cluster/openmpi    \
               sys-cluster/torque

    # Shell tools
    emerge -kn app-misc/tmux \
               app-shells/zsh
    install_data "${CONFDIR}/etc/zshrc" /etc/zsh

    # Editors
    emerge -kn app-editors/nvi \
               app-editors/vim
    eselect vi set nvi

    # Dev tools
    emerge -kn sys-devel/gcc             \
               dev-util/google-perftools \
               dev-vcs/git               \
               dev-libs/boost            \
               dev-cpp/eigen             \
               dev-cpp/tbb               \
               dev-python/pip            \
               dev-python/ipython        \
               dev-python/jupyter        \
               dev-python/matplotlib     \
               dev-python/numpy          \
               dev-python/scipy

    # Fonts
    emerge -kn media-fonts/dejavu \
               media-fonts/noto   \
               media-fonts/liberation-fonts

    # Misc.
    emerge -kn x11-apps/xeyes \
               media-gfx/imagemagick
}

update_world() {
    emerge --binpkg-respect-use=y -k -uDN @world
}

#------------------------------------------------------------------------------
# Internal utilities
#------------------------------------------------------------------------------

assert() {
    "$@" || die "Assertion failure: $*"
}

die() {
    echo "$*" >&2
    exit 1
}

install_data() {
    install -m 644 "$@"
}

install_script() {
    install -m 755 "$@"
}

#------------------------------------------------------------------------------

${1:-setup_auto}
