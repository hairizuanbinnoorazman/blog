+++
title = "Configuring Compute Storage"
description = "Configuring Compute Storage"
tags = [
    "google-cloud",
]
date = "2025-04-01"
categories = [
    "google-cloud",
]
+++

When we initially start playing around with compute instances in the cloud, we generally just deploy instances without thinking too much about it. We don't think about the application requirements or how CPU or Memory may require. But with experience, we then know the importance of providing sufficient resources to the applications that we install on the server - and a pretty huge one to think about the amount of storage we allocate to the server for our application.

On first glance, we may simply just create a instance with a pretty large size to it. However, the initial way of creating such instances on most cloud vendors and even in google cloud is that the main volume attached being attached to the instance is the "root" partition. This root partition generally tends to contain the OS files and kernel etc. It is not a problem to simply give a bigger disk storage to the root partition but it is actually not necessary per say. Let's go through a couple of examples where simply increasing the root partition may not be the most ideal

Reasons for having multiple partitions:

- Being able to precisely backup the database files and storage. It is quite easy to go to console and click on "Clone disk" option. However, if we are to mix both OS level files as well as database files - we are technically cloning all of such files - it is way harder to separate them. By being able to have just the databases file in a single volume - we can clone such disk - mount it to a different system and do be able to experiments such as upgrading database server versions or even upgrading linux OS/kernel
- Compliance reasons - can potentially have various diffent reasons for why different partitions exist: https://techgirlkb.guru/2019/08/how-to-create-cis-compliant-partitions-on-aws/

We won't go too deep on why we would want multiple partitions - however, we can look into how to do so.

## Setting up first instance

We can set up an instance with 2 disk attached to it. One of them would be the usual root disk (which would have our Linux OS - which would typically be Debian as the default). Second disk will be used to store data for a database (MariaDB) - which typically holds data in `/var/lib/mysql`

When we start the instance we can run the command:

```bash
lsblk
# NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
# sda       8:0    0  100G  0 disk 
# sdb       8:16   0   10G  0 disk 
# ├─sdb1    8:17   0  9.9G  0 part /
# ├─sdb14   8:30   0    3M  0 part 
# └─sdb15   8:31   0  124M  0 part /boot/efi
```

We would first need to format and partition the sda device.

```bash
sudo apt update
sudo apt install -y fdisk
sudo fdisk /dev/sda
# Press n for new partition
# Leave 1 as default for configuring first partition
# Press enter again to set the default first sector
# Press enter again to set the default last sector
# Press p to see the current configurations
# Press w to write configurations into stone for the device
sudo mkfs -t ext4 /dev/sda1
```

The disk is formatted now. We can then mount it and see how it goes

```bash
sudo mkdir -p /var/lib/mysql
sudo mount -t auto /dev/sda1 /var/lib/mysql
```

Next step would be to install MariaDB

```bash
sudo apt install -y mariadb-server
```

At this stage, if we list out the files in `/var/lib/mysql` folder; we would be able to see some files already there. Next step would be try to populate it so that we can do the next experiment of sorts

## Populating MariaDB server

We can do so by running the following:

```bash
# Become root user
sudo su -

# Go into mysql console
mysql

# Create database
CREATE DATABASE hehe;

# Create table
USE hehe;
CREATE TABLE Persons (
    PersonID int,
    LastName varchar(255),
    FirstName varchar(255),
    Address varchar(255),
    City varchar(255)
);

# Inserting some data
INSERT INTO Persons Values (0, 'aa', 'aa', 'aa', 'aca');
INSERT INTO Persons Values (1, 'aa', 'aa', 'aa', 'aca');
INSERT INTO Persons Values (2, 'aa', 'aa', 'aa', 'aca');

# Viewing data
select * from Persons;
# +----------+----------+-----------+---------+------+
# | PersonID | LastName | FirstName | Address | City |
# +----------+----------+-----------+---------+------+
# |        0 | aa       | aa        | aa      | aca  |
# |        1 | aa       | aa        | aa      | aca  |
# |        2 | aa       | aa        | aa      | aca  |
# +----------+----------+-----------+---------+------+
# 3 rows in set (0.001 sec)
```

## Cloning disk and mounting on different server

Once we have done some simple population of data, we can go back to Google Cloud Console and clone the disk. We can then attach this cloned disk to a diffent Google Cloud Instance.

We would need to run the following on the new instance.

```bash
# Update
sudo apt update

# Mkdir
sudo mkdir -p /var/lib/mysql

# Need to check it via some commands. e.g. lsblk
# Get the right device ID (/dev/xxxx)
sudo mount -t auto /dev/sda1 /var/lib/mysql
# At this point, you will have already seen a bunch of files already here related to db

# Install mariadb-server
sudo apt install -y mariadb-server
```

Now that we run the command

```bash
mysql

# Viewing data
select * from Persons;
# +----------+----------+-----------+---------+------+
# | PersonID | LastName | FirstName | Address | City |
# +----------+----------+-----------+---------+------+
# |        0 | aa       | aa        | aa      | aca  |
# |        1 | aa       | aa        | aa      | aca  |
# |        2 | aa       | aa        | aa      | aca  |
# +----------+----------+-----------+---------+------+
# 3 rows in set (0.001 sec)
```

We should be able to see same set of data

## Increasing size of disk

We can also simply increase the size of the disk but for such non-root partitions, it might take a bit of effort. First go to Google Cloud Console and increase the size of disk

An example of lsblk when we increase the disk size before resizing it within the instance

```bash
lsblk
# NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
# sda       8:0    0  180G  0 disk 
# └─sda1    8:1    0  150G  0 part /var/lib/mysql
# sdb       8:16   0   10G  0 disk 
# ├─sdb1    8:17   0  9.9G  0 part /
# ├─sdb14   8:30   0    3M  0 part 
# └─sdb15   8:31   0  124M  0 part /boot/efi
```

Notice the difference in size between sda and sda1

Next set of commands are to try to resize it (with heavy reference from Google Cloud Documenation)

```bash
sudo parted /dev/sda

# Goes to parted "window"
# Command on what to do next
resizepart

# Which parition to increase
1

# Whether to do it on live partition
Yes

# What's the last partition to extend to
100%

# Quit
quit

# Might require to run this part
sudo partprobe /dev/sda
```

We need to resize it on file system as well

```bash
sudo resize2fs /dev/sda1
```

## Conclusion

With that, we have somewhat played around with trying to make it easier to do snapshots and then from there do convenient disk cloning in order to be able to test out systems. One possible use case is where we can clone the data from a production system and then be able to run query or maybe make it easier to provide a staging environment for us to run integration test (there is no system better than testing it on production data after all)

## References

https://www.zdnet.com/article/how-to-format-a-drive-on-linux-from-the-command-line/  
https://cloud.google.com/compute/docs/disks/resize-persistent-disk  