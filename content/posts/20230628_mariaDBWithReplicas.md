+++
title = "Trying to create MariaDB replica server"
description = "Trying to create MariaDB replica server - use Golang app to simulate inserted records"
tags = [
    "golang",
    "google-cloud",
]
date = "2023-06-28"
categories = [
    "golang",
    "google-cloud",
]
+++

A common architectural pattern for relational databases is to create an additional replica server. This pattern usually come up due because most applications are usually read heavy - data is usually read to be presented to users.

The whole blog post would be to show how we can quickly get started (naturally - there could be better configuration that we can use here such as limiting which databases which are to be replicated to other replicas.)

## Setting up MariaDB on server

We are not utilizing the cloud database solutions provided by the cloud vendors - we won't learn too much if we simply rely on that mechanism.

First, we would need to create a normal linux/debian server. We would then need to install the mariadb server and its corresponding client.

```bash
sudo apt update
sudo apt install -y mariadb-server mariadb-client
```

We can check that the database is installed the correctly by first going into the MySQL CLI tool.

```bash
mysql
```

Then, we can try to list the databases within it by running the following SQL command:

```bash
SHOW DATABASES;
```

It should respond with the following:

```bash
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
```

## Testing the installed Database with an application

Now that we mariadb installed, we would need something to simulate the application which would be inserting the data into the databases. We can utilize the following application - the application would even run a migration step without requiring a separate sql script to do so. https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/appwithmysql

In order to use the application mentioned in the github link, we would first need to create the database as well as the corresponding users.

```bash
CREATE DATABASE testmysql;
CREATE USER username IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON `testmysql`.* TO 'username';
```

Once we have this in place, we can a `scp` of our binary from our application to the server. We should be able to run it with no issue. I'm assume the same binary name was used - which is **recordmaker**

```bash
scp recordmaker <ssh user>@<ip address>:/home/<ssh user>/recordmaker
```

After which, we can ssh into the server and start the recordmaker binary. If there are permission issues - might need to alter it with chmod etc.

```bash
# In /home/<ssh user>/
./recordmaker
```

## Alter server to be the primary database server

Now that we have an application to test the entire mechanism. First we need to setup primary server; we would need to also ensure that the primary is accessible by the other replicas. By default, MariaDB is setup to also be binded to 127.0.0.1 - it cannot be accessed from hosts from outside the server it resides in. We need to change this to 0.0.0.0. This is done by changing it in the following file: `/etc/mysql/mariadb.conf.d/50-server.cnf`

In the `mysqld` section

```bash
[mysqld]
... #Other configuration
# bind-address 127.0.0.1 - change this to 0.0.0.0 (similar as the next line) 
bind-address = 0.0.0.0
... # Other configuration
```

In the `mariadb` section

```bash
[mariadb]
log-bin
log-basename=master1
```

We would then need tto restart the database to get these configurations to be used for the mariadb - configuration changes are usually not changed on the fly. We need to make sure that the database is properly binded to 0.0.0.0. We can run the following to check it: ` netstat -tlnp`

```
# netstat -tlnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:3306            0.0.0.0:*               LISTEN      4369/mariadbd   
```

The next step would be to once again to go into MySQL CLI and create the following user:

```bash
CREATE USER 'replication_user'@'%' IDENTIFIED BY 'bigs3cret';
GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'%';
```

## Create the replica server

We would need to replicate the steps to setup MariaDB on the replica server. We would also need to reconfigure it the 

For the `mysqld` section

```bash
[mysqld]
... #Other configuration
server-id = 2
... # Other configuration
```

For the `mariadb` section

```bash
[mariadb]
log-bin
log-basename=slave1
```

We would also need to restart the database after this.

## Copy the data over from primary to replicas

This is the important bit here; we would need to "bootstrap" our replica server with the data from our primary server. I tried without it and replicating won't even work (unless we bootstrap the primary + replica without even putting in the data into the server)

The instructions for this is available in the following section of the replication reference page on MariaDB documentation: https://mariadb.com/kb/en/setting-up-replication/#getting-the-masters-binary-log-co-ordinates. For this blog post, we would just list down the commands that would make this happen.

```bash
# In the primary server
# In MySQL tool 
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS; #make sure we copy the values for log file and log pos. It is needed for later section

# In bash of primary db
mariadb-dump --all-databases
```

We would then copy the data over to the replica server

```bash
mariadb < backup-file.sql
```

This would bootstrap our replica database with the required data.

Then, on the primary server, we can simply run the following command:

```bash
UNLOCK TABLES;
```

## Final configuration of replicas MariaDB server

We would need to run the following command on our replica server.

```bash
CHANGE MASTER TO
  MASTER_HOST='instance-1',
  MASTER_USER='replication_user',
  MASTER_PASSWORD='bigs3cret',
  MASTER_PORT=3306,
  MASTER_LOG_FILE='master1-bin.000001',
  MASTER_LOG_POS=330,
  MASTER_CONNECT_RETRY=10;
```

We can then start the slave thread

```bash
START SLAVE;
```

We can then check if slave is running and replication works as expected. 

```bash
SHOW SLAVE STATUS \G
```

If there are any issues, check out the following forum page:  
https://stackoverflow.com/questions/1724191/mysql-slave-i-o-thread-not-running

## One more round of testing

To make sure that the entire replication process is working, we can utilize our friend, recordmaker that would create database records. As we start running it, we can go to replica server and keep running the following SQL query:

```sql
select * from `testmysql`.`users` order by `updated_at` desc limit 10 ;
```

We will see that there is some slight replication delay but it should be roughly ok for application use. It could be 20-30s delay at times but it could be the amount of data being generated by the `recordmaker` tool.

## Final thoughts

Setting up the above is such a pain - automation is definitely needed. The entire process is pretty much error prone - just one misstep would easily mean bad replication leading to database corruption making it impossible to use.

## References
  
- Following blog post is heavily references from the following page:  
  https://mariadb.com/kb/en/setting-up-replication/
- Need to "expose" mysql to other 
  https://mariadb.com/kb/en/configuring-mariadb-for-remote-client-access/
- https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/appwithmysql
- https://stackoverflow.com/questions/21664091/mariadb-not-allowing-remote-connections
- https://dba.stackexchange.com/questions/51076/copy-all-data-to-slave-before-mysql-replication-connect