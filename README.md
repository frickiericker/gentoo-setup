# Gentoo-Setup

This repository contains setup scripts and configuration files for a small
Gentoo Linux cluster.

## Minimal BIOS/GPT/systemd/static-IP installation

`minimal_install.sh` installs minimal Gentoo Linux system from livecd. The
system would be laid out on GPT partitions, boots via BIOS (no UEFI) and uses
systemd as the init system. IP address is static. Use this minimal system as a
starting point to set up your own system.

Usage: Change `UPPERCASE_VARIABLES` in the installation script such as `IPV4`
to match your host hardware and environment. Boot Gentoo livecd on the host
machine and put modified script somewhere in the livecd system. Then execute
the script:
```
    (livecd) ~ # ./minimal_install.sh
```
After successful completion of the script, reboot the system. Login as root
and issue the following command:
```
    ~ # ./minimal_install.sh postinstall
```
to finish the installation.

## Example setup: Parallel computing cluster node

Starting from the minimal Gentoo Linux system, `setup_node.sh` sets up a
cluster node used for parallel scientific computing. In this cluster the
portage tree is owned by master node and shared across worker nodes via NFS.
Single node builds binary packages, and other nodes use prebuilt packages.

Other random characteristics:
 - User information is obtained from an external NIS server
 - Home directories are mounted from an external NFS server

The setup script contains a procedure to build such a system. Also the `etc`
and `sys` directories in this repository contain configuration files installed
by the setup script.
