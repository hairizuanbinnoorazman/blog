+++
title = "Trying ZFS filesystems"
description = "Trying ZFS filesystem"
tags = [
    "google-cloud",
    "devops",
]
date = "2025-07-20"
categories = [
    "google-cloud",
    "devops",
]
+++

There is a technical challenge and interesting requirement in my job that requires lightweight snapshot capability of a folder/set of files. Technically, it should be ok to simply create a volume snapshot on the cloud vendor of this - however - creating such snapshots actually take a lot of time and potentially, a lot of space - it's not the cheapest solution for this.

However, I do see online that there are a bunch of different filesystems on the market. The common one that we generally use is ext3 or ext4 -> those are journalling file system. They are file systems that are focused on reliability on performance - reliability in the sense where if anything goes wrong, the data is not loss (and this is definitely a primary aim of a storage solution - to store stuff and ensure that the stuff doesn't go missing). There is another file system though - the CoW (Copy on Write) file systems - I mostly started hearing of it due to Docker, there is a need to ensure that the layers on the container is lightweight. A primary feature for some of them is the capability to be able to create very quick lightweight snapshots of the file system and be able to review and rollback as and when necessary. We can think of it similar to doing incremental backups (to save resources) on file systems. For most companies, they do it via external systems on the usual file systems like the ext3 or ext4 but imagine if you use CoW systems - the snapshots are considered baked into the file system itself.

Let's go straight to demo

## Setting up the machine

We first need to setup the machine. I mostly use Rocky environments at work - so I'm gonna stick to them for this post.

- Create a VM on Google Cloud Compute
  - Change OS to Rocky 9
  - Choose e2-standard-4 (Reason for choosing bigger instance is due to installation of some of the packages that quite a bunch of resources)
- Add 2 extra volumes with 30GB disk (these will be used for ZFS)

## Setting up ZFS on Rocky 9

```bash
sudo dnf install epel-release -y
sudo dnf install -y https://zfsonlinux.org/epel/zfs-release-2-2.el9.noarch.rpm

# Apparently, ZFS is supported on LTS kernel
# This one would allow us to allow us to use on different kernel versions
sudo dnf groupinstall "Development Tools" -y
sudo dnf install kernel-devel -y
sudo dnf install zfs -y

# Reboot machine so that we can recognize the zfs module
sudo reboot
```

## Creating the file system with ZFS

```bash
sudo fdisk -l
# $ sudo fdisk -l
# Disk /dev/sdc: 30 GiB, 32212254720 bytes, 62914560 sectors
# Disk model: PersistentDisk  
# Units: sectors of 1 * 512 = 512 bytes
# Sector size (logical/physical): 512 bytes / 4096 bytes
# I/O size (minimum/optimal): 4096 bytes / 4096 bytes


# Disk /dev/sdb: 30 GiB, 32212254720 bytes, 62914560 sectors
# Disk model: PersistentDisk  
# Units: sectors of 1 * 512 = 512 bytes
# Sector size (logical/physical): 512 bytes / 4096 bytes
# I/O size (minimum/optimal): 4096 bytes / 4096 bytes

sudo zpool create -m /usr/share/pool new-pool /dev/sdb /dev/sdc
# $ df
# Filesystem     1K-blocks    Used Available Use% Mounted on
# devtmpfs            4096       0      4096   0% /dev
# tmpfs            8055276       0   8055276   0% /dev/shm
# tmpfs            3222112    8716   3213396   1% /run
# efivarfs              56      24        27  48% /sys/firmware/efi/efivars
# /dev/sda2       20699136 5433124  15266012  27% /
# /dev/sda1         204580    7208    197372   4% /boot/efi
# tmpfs            1611052       4   1611048   1% /run/user/1000
# new-pool        59932288     128  59932160   1% /usr/share/pool

sudo zpool status
# $ sudo zpool status
#   pool: new-pool
#  state: ONLINE
# config:

#         NAME        STATE     READ WRITE CKSUM
#         new-pool    ONLINE       0     0     0
#           sdb       ONLINE       0     0     0
#           sdc       ONLINE       0     0     0

# errors: No known data errors

# So that we can view read only snapshot folders
sudo zfs set snapdir=visible new-pool
```

At this stage - we can already start using the zfs file system

## Using ZFS and using snapshotting capabilities

```bash
zfs list -t snapshot
# no datasets available

cd /usr/share/pool
sudo mkdir data
# Replace xxx with your user
sudo chown xxx:xxx data
cd data
touch example.txt

# Creating snapshot testing01
# This will have only example.txt in data folder
sudo zfs snapshot new-pool@testing01

touch testing02.txt
touch example02.txt
sudo zfs snapshot new-pool@testing02

base64 /dev/urandom | head -c 100 > exammple03.txt
base64 /dev/urandom | head -c 100 > testing03.txt
sudo zfs snapshot new-pool@testing03

base64 /dev/urandom | head -c 100000 > example02.txt
base64 /dev/urandom | head -c 100000 > testing02.txt
sudo zfs snapshot new-pool@testing04

# View the read only snapshots of the file system
cd /usr/share/pool/.zfs/snapshots

# View difference of snapshots of file system
$ sudo zfs diff new-pool@testing03 new-pool@testing04
M       /usr/share/pool/data/testing02.txt
M       /usr/share/pool/data/example02.txt
```

Some interesting things:
- We can't set a symbolic link to a snapshot - it'll complain that the file system being linked to is a read only file system and that won't for it.

## Cleanup

We can simply delete the instance once we are done. An important thing to note here is that we also would need to remove the additional disks being used to power the zfs file systems - these are not automatically removed.

## Untested 

This is some commands I haven't fully understood or tested it yet

```bash
# To bind mount a snapshot
# A previous attempt to mount the snapshot resulted in difficulties to unmount (due to busy device)
# Also, forcing an unmount via umount -l also led to us not being able to access the dir on .zfs snapshot folder. It complains of too many symbolic links (probably due to bad commnads and procedures)
mkdir /mnt/snap1
sudo mount --bind /tank/mydata/.zfs/snapshot/snap1 /mnt/snap1
```