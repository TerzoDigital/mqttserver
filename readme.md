# Overview

This repository contains files to support the generation of a docker machine which hosts an MQTT server.

The MQTT server used is the latest version of Eclipse Mosquitto v2. The docker container is based on the eclipse-mosquitto:2 image. See the documentation on [Docker Hub](https://hub.docker.com/_/eclipse-mosquitto)

A useful resource for configuration of the Mosquitto server is [this Cedalo document](https://cedalo.com/blog/mosquitto-docker-configuration-ultimate-guide/).

# File description

The following files are included in the folder:

- **docker-compose.yml** A docker compose file to create the docker machine.
- **generate-certs.sh** A script to generate certificates within a *certs* folder.
- **readme.md** This file.
- **config/mosquitto.conf** The Mosquitto configuration file.
- **config/passwd_file** A password file for the Mosquitto broker.

The password file contains a single entry:

- User: **user1**
- Password: **Elephant1**

# Running the Docker machine

The instructions below assume that the git repository is checked out to a Linux machine.

## Quick setup

After checking out this repo and changing into the checked out folder, do the following:

```
sudo chown 1883:1883 config/*
chmod +x *.sh
sudo chown 1883:1883 certs/*
mkdir data
chmod 777 data
mkdir log
chmod 777 log
docker-compose up -d
```
After this the docker machine will be running as "mosquitto". To check the machine is running:
```
docker ps
```
To view the logs of the machine:
```
docker-compose logs -f mosquitto
```
Using CTRL-C to end the follow of the logs. Or do not use the -f if you do not want to follow.

To examine the logs, change config files or view certificates on the docker container, log onto the container with:
```
docker exec -it -u 1883 mosquitto sh
```
Use "exit" at the shell prompt to return to the host.

To close down the machine use:
```
docker-compose down
```

## Setting up a passwd_file and an initial configuration

The passwd_file which is in the git repository is normally held on the hosts file system and shared with the docker machine through a volume. This brings two possible problems:

1. **Permissions**, the files on the host need the correct permissions to allow the mqtt broker on the host to use them.
2. **Creation using correct version of utilities**, the passwd_file needs to be compatible with the version of Mosquitto in the docker machine.

The docker machine created from the Mosquitto image includes a user and group with ID 1883. To ensure permissions are OK use the following commands in the host.

```
sudo chown 1883:1883 filename
```

If you want to create a different password file then you can follow the instructions below. These create a temporary docker image, creates the password file in there and then copies it out to a new passwd_file ready for use in the docker machine through docker-compose. 

- Checkout the current repo
- Change into the checked out folder
- Delete config/mosquitto.conf
- Delete config/passwd_file
- Touch config/mosquitto.conf to get an empty configuration file
- correct permissions with
```
sudo chown 1883:1883 config/mosquitto.conf
```
- Run up the docker machine with the blank configuration file where path is replace with the relevant path for your machine.
```
docker run -it -d --name mos1 -p 1883:1883 -v $HOME/path/config/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto:2
```
- Log into the docker machine as mosquitto using
```
docker exec -it -u 1883 mos1 sh
```
- Create a password file using the below and replacing user_name with the name of your choice
```
mosquitto_passwd -c /mosquitto/passwd_file user_name
```
- Copy the contents of the new passwd_file
- Exit the docker machine
- in the config folder touch passwd_file
- Edit the passwd_file and paste in the contents from the docker machine that you copied
- Dispose of the docker machine and then remove it with
```
docker stop mos1
docker container rm mos1
```
- Restore the original configuration file using
```
git checkout -- config/mosquitto.conf
```
- Correct file permissions with
```
sudo chown 1883:1883 config/mosquitto.conf
sudo chown 1883:1883 config/passwd_file
```
- Run the docker machine using docker-compose as described elsewhere in this file.

## Creating certificates in support of the Mosquitto broker

If the generate-certs.sh file has just been checked out of git, you may need to alter the permissions of the file so that it can be executed. Use the following to do that:

```
chmod +x generate-certs.sh
```

Run the script using the following command:

```
./generate-certs.sh
```

This will generate the following files in a certs folder, which will be created if it does not already exist.

- **ca.crt** The CA certificate.
- **ca.key** The CA private key.
- **ca.srl** The CA serial file
- **server.crt** The server certificate (signed by the CA)
- **server.key** The server private key
- **client.crt** An example client certificate (signed by the CA)
- **client.key** An example server private key

Note that a single client key and certificate are generated, ready for use by one client in mutual TLS (mTLS). For more clients, use the instructions within the file to generate more certificates.

## Turning on and off Mutual TLS (mTLS)

To turn on and off Mutual TLS uncomment or comment the following lines in "config/mosquitto.conf":

```
require_certificate true
use_identity_as_username false
```

When require_certificate is set to true, then all clients must produce vaid certificates to connect to the broker. This is mutual TLS authentication.

Note that if *use_identity_as_username* is set to true, then the CN from the certificate will be used as the username.

## Running and checking the machine

To run the docker machine use the following. This will create a docker machine called "mosquitto".

```
docker-compose up -d
```

To stop the docker machine use the following. This will stop the machine and delete the create container.

```
docker-compose down
```

Whilst the machine is running use the following to view the logs the broker is producing. To stop following the logs press *CTRL-C*.

```
docker-compose logs -f mosquitto
```

## Testing the broker

To test the broker is working, try using MQTT explorer and setting up the relevant connection details.

From the command line within the container one can test publication using
```
mosquitto_pub -i mos_pub1 -t "MyTopic" -m "MyMessage" -u user1 -P Elephant1 
```
Subscription can be tested using
```
mosquitto_sub -i mos_sub1 -t "MyTopic" -u user1 -P Elephant1 -d
```
In all of the above MyTopic should be replaced with the topic you want to use. MyMessage should be replaced with the message you wish to send. The username "user1" and password "Elephant1" are the defaults for the repo and should be replaced with other values if you have changed them.

