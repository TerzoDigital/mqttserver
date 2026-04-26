# Overview

This repository contains files to support the generation of a docker machine which hosts an MQTT server.

The MQTT server used is the latest version of Eclipse Mosquitto v2. The docker container is based on the eclipse-mosquitto:2 image. See the documentation on [Docker Hub](https://hub.docker.com/_/eclipse-mosquitto)

A useful resource for configuration of the Mosquitto server is [this Cedalo document](https://cedalo.com/blog/mosquitto-docker-configuration-ultimate-guide/).

# File descriptions

The following files are included in the folder:

- **compose.yml** A docker compose file to create the docker machine.
- **generate-certs.sh** A script to generate certificates within a *certs* folder.
- **initial-setup.sh** A script to perform the initial setup of the MQTT server.
- **manage-mqtt-user.sh** A script to allow the addition or removal of MQTT users.
- **readme.md** This file.
- **config/mosquitto.conf** The Mosquitto configuration file.
- **config/passwd_file** A password file for the Mosquitto broker.

# Initial password file settings

The password file contains a single entry:

- User: **user1**
- Password: **Elephant1**

# Running the Docker machine

The instructions below assume that the git repository is checked out/cloned to an Ubuntu Linux machine.

## Quick setup

After checking out/cloning this repo and changing into the checked out/cloned folder, do the following:

```
./initial-setup.sh
docker compose up -d
```
The initial-setup.sh script performs actions to setup the docker machine and supporting folders for first use. These actions include:

- Creating a CA and certificates for use by the broker and clients.
- Creating data and log folders to support the docker machine when running.
- Altering ownership and permissions to the supporting folders to ensure they are accessible.

After this a docker machine, as specified by the compose.yml file, is created and run. Please note the following about that machine:

- The container is called "mosquitto".
- The service being run is also called "mosquitto".
- Once the service is started, Docker will keep the service running unless it is deliberately stopped. This includes restarting the service after the host machine is restarted.
- The MQTT server is listening on ports 1883 (MQTT without TLS) and 8883 (MQTT with TLS).
- The MQTT server is also listening on port 9001 (MQTT over WebSockets) but this has not been tested.
- MQTT access must be authenticated and out of the box the user and password shown [above](#initial-password-file-settings) are used.
- For MQTT using TLS, a CA with locally signed ceryificates for the broker and client are set up. See [below]() for more information on this.

## Managing the Docker machine

To check whether the machine and service are running:
```
docker compose ps
```
> [!TIP]
>Pay attention to the time the machine has been running for, this should reflect the time since the machine was started. If there are configuration issues, then the machine may keep restarting!

To view the logs of the machine:
```
docker compose logs -f mosquitto
```
Using *CTRL-C* to end the follow of the logs. Or do not use the -f if you do not want to follow.

To examine the logs, change config files or view certificates on the docker container, log onto the container with:
```
docker exec -it -u 1883 mosquitto sh
```
Use "exit" at the shell prompt to return to the host.

To close down the machine use:
```
docker compose down
```
To run the docker machine use the following. This will create a docker machine called "mosquitto" and immediately detach from the machine (using the *-d* option), allowing you to continue at the prompt.
```
docker compose up -d
```
If you leave the *-d* option off the command, as shown below:
```
docker compose up
```
You will remain attached to the docker machine following the logs being produced by the machine. This can be useful for debugging issues. 

## Changing the broker configuration

The broker is configured through the *config/mosquitto.conf* file. The contents of the text file are described on the [Mosquitto manual page](https://mosquitto.org/man/mosquitto-conf-5.html). They may be edited from the host using the command:
```
sudo nano config/mosquitto.conf
```
The use of *sudo* is required as the ownership of the file is set to 1883 and not the current user. Replace *nano* with the editor of your choice if *nano* is not your preferred editor.

## Adding and deleting MQTT users

The unchanged code from Github, is configured to use authentication with the user and password shown [above](#initial-password-file-settings). Authentication is configured for use through the line below which appears in the *mosquitto.conf* file.
```
allow_anonymous false
```
Changing *false* to *true* would permit anaonymous access to the broker. Assuming you continue to use authentication, it is possible to add or delete users for the broker using the supplied script. To add another user use:
```
./manage-mqtt-user.sh add username password
```
Where *username* is the name of the user you wish to add, and *password* is the password they should be added with.

To delete a user use the following:
```
./manage-mqtt-user.sh delete username
```
Where *username* is the name of the user you wish to delete.

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

## Using TLS with the broker

### Forcing the use of TLS

To force the broker to only use a TLS method of connection, it is necessary to remove the listener for the non-TLS mode of connection. To do this comment our or remove the following line from the *mosquitto.conf* file.
```
listener 1883
``` 
To comment this line out place a # at the start of the line.

### Using TLS with locally generated certificates

During the execution of the *initial-setip.sh* script, another script *generate-certs.sh* is run to fo the following:

- Create a local CA (Certificate Authority)
- Create a key pair for the broker and a certificate signed by the CA
- Create a key pair for a client and a certificate signed by the CA

The *generate-certs.sh* script is fairly self explanatory. You can examine and modify the script to meet your own ends. It will for example show the Common Names CNs used for the various created certificates. For example, the client certificate has the CN *test-client*.

After execution the *generate-certs.sh* script will generate the following files in a certs folder, which will be created if it does not already exist.

- **ca.crt** The CA certificate.
- **ca.key** The CA private key.
- **ca.srl** The CA serial file
- **server.crt** The server certificate (signed by the CA)
- **server.key** The server private key
- **client.crt** An example client certificate (signed by the CA)
- **client.key** An example client private key

Note that a single client key and certificate are generated, ready for use by one or more clients in mutual TLS (mTLS). More client certificates and keys can be generated by using the instructions within the script file to generate more certificates.

> [!NOTE]
>When the *initial-setup.sh* script is run it will leave all certificates and keys with the right ownership and permissions for use by the broker within the Docker machine. If new certificates or keys are generated by running commands manually or via rerunning the *generate-certs.sh* script again, it will be necessary to alter the ownership and permissions again. See [this section](#issues-in-initial-setup) for advice on how to do that.

To enable an MQTT client to use mTLS do the following:

- Make the CA certificate (*ca.crt*) available to the client.
- Make the client private key (*client.key*) available to the client.
- Make the client certificate (*client.crt*) available to the client.

How these files are 'made available' will depend on the specific client.

### Using TLS with a publically signed certificate

### Turning on and off mutual TLS (mTLS)

TLS can be single ended (where the server provides a certificate to the client which permits the client and server to create a secure connection) or double ended (where the server provides a certificate and the cient provides a certificate). Double ended is known as mutual TLS or mTLS.

To turn on and off mutual TLS ensure the following line appears uncommented in "config/mosquitto.conf":

```
require_certificate true
```

When *require_certificate* is set to *true*, then all clients must produce valid certificates to connect to the broker. This is mutual TLS authentication. When *require_certificate* is set to *false* then only the server will provide the certificate.

> [!NOTE]
>Normal TLS and mTLS are used over port 8883. Connections made over port 1883, do not use TLS or mTLS.

### Taking the username from the client certificate

There are a number of options which permit the username or client ID used by the broker during logon to be taken from the certificate, ignoring any provided at logon. Use the following to get the CN (Common Name) specified in the certificate to be used as the username for logon:

```
use_identity_as_username true
```

You can read more about this on the [Mosquitto manual page](https://mosquitto.org/man/mosquitto-conf-5.html) and in this [useful article](http://www.steves-internet-guide.com/creating-and-using-client-certificates-with-mqtt-and-mosquitto/).

## Issues in initial setup

To make initial setup easier the script *initial-setup.sh* is provided. This section discusses some of the issues that the script tries to address. The section is provided as extra information to help with further configuration of the broker.

The *passwd_file* and *mosquitto.conf* file, which are in the git repository, are accessible on the hosts file system and shared with the docker machine through a volume. This brings two possible problems:

1. **Permissions**, the files on the host need the correct permissions to allow the mqtt broker on the host to use them.
2. **Creation using correct version of utilities**, the files need to be compatible with the version of Mosquitto in the docker machine. Although this is less of a problem for the *mosquitto.conf* file it is important that the *passwd_file* is created using the correct version of Mosquitto.

The docker machine created from the Mosquitto image includes a user and group with ID 1883. To ensure permissions are OK, the user and group for the files or folders within the host are set to 1883 and 1883 using a command like the following:
```
sudo chown 1883:1883 filename
```
To change the permiisions and ownership of all files within a folder and the folder itself use:
```
sudo chown -R 1883:1883 foldername
```

