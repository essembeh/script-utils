# Remote Borg - Tool to backup locally a remote server

[Borgbackup](https://github.com/borgbackup/borg) has been the perfect tool to manage my backups for years now, but I found fustrating not being able to backup remote servers from my workstation like `borg create ./myrepo::{now} ssh://root@server/etc` 

There are some alternative to use `sshfs` and mount the remote filesystem, but I don't like this workaround and for security reasons I don't want to store keys to acces my workstation on servers.

[Remoteborg](remoteborg.py) is a standalone Python3 script to deal with this use case: *I want to backup a remote server from (and on) my machine*.


# Prerequisites

> The use case: you have a local *workstation* and a remote *server*. You created a *borg repository* on your *workstation* and you want to backup the *server* in it.
The *server* is visible from the *workstation* but the *workstation* is not visible from the *server*.

First, you need to have *borgbackup* installed on both machines:
```sh
$ sudo apt install borgbackup
```

On the *workstation* you need to have a running *SSH server*
```sh
$ sudo apt install openssh-server
```
You need a SSH key to be able to connect to your local user via ssh, which could sound useless, but it is not :)
```sh
$ ssh-keygen -b 4096 -f ~/.ssh/id_borgbackup
$ ssh-copy-id localhost -i ~/.ssh/id_borgbackup
```

Here we are!


# Usage 

> Note: by default remoteborg prints the command to be executed and ask for confirmation before running it (you can use `--yes` to bypass the confirmation)

Here is a simple usage to backup `/etc` from my *server* in a local `server.borg` repository:
```sh
$ remoteborg -t -d server.borg root@server --progress  create ::{now} /etc
Command: ssh -p 22 -A -R 47022:localhost:22 root@server -t BORG_REPO=ssh://seb@localhost:47022/home/seb/server.borg borg --progress create '::{now}' /etc
Execute command? (y/N) y
----------------------------------------
The authenticity of host '[localhost]:47022 ([::1]:47022)' can't be established.
ECDSA key fingerprint is SHA256:YNboF7BY2LIZt0s3ojW1g8QqCPobw78uVeeqrDIM.
Are you sure you want to continue connecting (yes/no)? yes
Remote: Warning: Permanently added '[localhost]:47022' (ECDSA) to the list of known hosts.
Connection to server closed.  
```

> Note: on first run, you will probably get an error `Remote: Host key verification failed`, you may have to force *TTY* using the `--tty/-t` option (only once). You will then be able to accept the fingerprint of your *workstation* on you *server* because the *server* accesses the borg repository through the SSH tunnel for the first time.


## Using args file

You can specify borg arguements in a simple text file using `remoteborg --args <FILE> ...` 

```sh
$ cat remoteborg.args
# This is a comment
create 
--progress 
--stats 

# TAG
::{now}

# FOLDERS
/etc/
/var/backups/
/root/

$ remoteborg --args remoteborg.args -d ./server.borg/ root@server
Command: ssh -p 22 root@server -A -R 47022:localhost:22 BORG_REPO=ssh://seb@localhost:47022/home/seb/server.borg borg create --progress --stats ::{now} /etc/ /var/backups/ /root/
Execute command? (y/N) y
----------------------------------------
------------------------------------------------------------------------------  
Archive name: 2020-04-17T00:35:58
Archive fingerprint: 7ac9626d4c658406ee1039c692bafc5a592db9ee68e59d8b279370e686765e1e
Time (start): Fri, 2020-04-17 00:35:59
Time (end):   Fri, 2020-04-17 00:36:01
Duration: 1.27 seconds
Number of files: 580
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                3.56 MB              2.04 MB            496.76 kB
All archives:                5.38 MB              2.78 MB              1.24 MB

                       Unique chunks         Total chunks
Chunk index:                     547                 1107
------------------------------------------------------------------------------
```

> Note: Empty lines and lines starting with a `#` will be ignored


# Documentation

```sh
$ remoteborg --help
usage: remoteborg [-h] [-d DIR] [-t] [-y] [--args FILE] [-p PORT]
                  [--local-user USER] [--local-port PORT] [--local-host HOST]
                  [--tunnel PORT]
                  REMOTE_HOST ...

positional arguments:
  REMOTE_HOST           remote ssh host
  BORG_ARGS             borg arguments

optional arguments:
  -h, --help            show this help message and exit
  -d DIR, --repodir DIR
                        path to borg repository
  -t, --tty             force pseudo-terminal allocation for ssh connection
                        (might be required to accept ssh fingerprints)
  -y, --yes             do not ask confirmation before executing command
  --args FILE           use borg arguments from file
  -p PORT, --remote-port PORT
                        remote server ssh port
  --local-user USER     local ssh user who can access to the borg repository
                        (default is current user)
  --local-port PORT     local ssh port (default is 22)
  --local-host HOST     local ssh host (default is localhost)
  --tunnel PORT         port used to setup the ssh tunnel (you should change
                        it if 47022 is already taken)
```
