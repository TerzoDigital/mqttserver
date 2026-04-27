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
- For MQTT using TLS, a CA with locally signed certificates for the broker and client are set up. See [below](#using-tls-with-locally-generated-certificates) for more information on this.

> [!WARNING]
>The username and password displayed above are useful for getting off the ground. However, as they are openly available on this page, it is strongly suggested that a new user and password are created and the user1 user deleted once you are comfortabel with operation. Follow the instructions [below](#adding-and-deleting-mqtt-users) to remove and add users.

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
Changing *false* to *true* would permit anaonymous access to the broker. Assuming you continue to use authentication, it is possible to add or delete users for the broker using the supplied script. To add a user use:
```
./manage-mqtt-user.sh add username password
```
Where *username* is the name of the user you wish to add, and *password* is the password they should be added with.

To delete a user use:
```
./manage-mqtt-user.sh delete username
```
Where *username* is the name of the user you wish to delete.

In both cases, the script will alter the *config/passwd-file* by using a mosquitto command within the docker client.

## Testing the broker

To test the broker is working, try using MQTT explorer and setting up the relevant connection details.

From the command line within the container one can test publication using:
```
mosquitto_pub -i mos_pub1 -t "MyTopic" -m "MyMessage" -u user1 -P Elephant1 
```
Subscription can be tested using:
```
mosquitto_sub -i mos_sub1 -t "MyTopic" -u user1 -P Elephant1 -d
```
In all of the above MyTopic should be replaced with the topic you want to use. MyMessage should be replaced with the message you wish to send. The username "user1" and password "Elephant1" are the defaults for the repo and should be replaced with other values if you have changed them.

Access to the command line in the broker can be achieved using the following command from the docker host:
```
docker exec -it -u 1883 mosquitto sh
```
Use "exit" at the shell prompt to return to the host once you have completed testing.

## Using TLS with the broker

### Forcing the use of TLS

To force the broker to only use a TLS method of connection, it is necessary to remove the listener for the non-TLS mode of connection. To do this comment our or remove the following line from the *mosquitto.conf* file.
```
listener 1883
``` 
To comment this line out place a # at the start of the line.

### Turning on and off mutual TLS (mTLS)

TLS can be single ended or double ended. Single ended TLS can be known as Standard TLS. Double ended is known as mutual TLS or mTLS. mTLS offers security advantages over Standard TLS. mTLS is a key part of a zero trust architecture.

In Standard TLS only the server needs to provide a certificate to the client. The identity of the server is validated by the client and a secure and encrypted communications session is set up using the credentials provided by the validated server. In mTLS, both the server and the client must provide certificates to each other, the cleint once again validates the server, but in mTLS the server also validates the client. This is much more secure that Standard TLS. 

To turn on and off mTLS ensure the following line appears uncommented in "config/mosquitto.conf":

```
require_certificate true
```

When *require_certificate* is set to *true*, then all clients must produce valid certificates to connect to the broker. This is mutual TLS authentication. When *require_certificate* is set to *false* then only the server will provide the certificate.

> [!NOTE]
>Normal TLS and mTLS are used over port 8883. Connections made over port 1883, do not use TLS or mTLS. To ensure full security remember to disable the Non TLS port 1883 as described [above](#forcing-the-use-of-tls).

### Taking the username from the client certificate

There are a number of options which permit the username or client ID used by the broker during logon to be taken from the certificate, ignoring any provided at logon. Use the following to get the CN (Common Name) specified in the certificate to be used as the username for logon:

```
use_identity_as_username true
```

You can read more about this on the [Mosquitto manual page](https://mosquitto.org/man/mosquitto-conf-5.html) and in this [useful article](http://www.steves-internet-guide.com/creating-and-using-client-certificates-with-mqtt-and-mosquitto/).

### Using TLS with locally generated certificates

During the execution of the *initial-setip.sh* script, the script *generate-certs.sh* is also run. This sets up the broker to use locally generated certificates and provides all the relevant files to do that. Specifically it does the following:

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

Locally signed certificates may be the preferred option for some users who wish to be in full control of their PKI (Private Key Infrastructure). In some cases though, users may wish to use publically signed certificates. These are certificates which are signed through a chain of CAs (Certificate Authorities) where the head of that chain is a publically well known and trusted CA. The certificates for such trusted CAs are often built into operating systems. To validate the certificate being offered, a system checks that the certificate is correctly signed by its CA, that the CAs ceritificate is correctly signed by the next CAs certificate, and so on until the last certificate is the one built into the operating system. This is exactly how secure web pages (HTTPS) work with your browser, although there is a host of detail missing from the description above! Suffice to say that users may select to use a publically signed certificate and this section describes how that can be done.

Although there are many ways in which a publically signed certificate could be acquired, this section explains how that can be done through [LetsEncrypt](https://letsencrypt.org/) using the [Certbot](https://certbot.eff.org/) mechanism and proving that we are who we say we are by altering a DNS record in our controlled domain. So note that this method is for public signed and internet based operation. No cost is involved in this process as LetEncrypt and Certbot are freely provided in an effort to enhance security on the internet.

The use of publically signed certificates is most prevalent in the web space, so many article describing how to acquire a certificate concentrate on that aspect. In this case we need the certificate for an MQTT server and so there are some small differeneces to that normal procedure. Bearing this in mind a number of sources have been used to determine the method of acquiring a publically signed certificate through LetsEncrypt. They are:

- The [LetsEncrypt Getting Started Page](https://letsencrypt.org/getting-started/). This page is heavily web focussed but does include links to the LetsEncrypt documentation and the Certbot ACME client.
- The [Certbot User Guide](https://eff-certbot.readthedocs.io/en/stable/using.html).
- A [blog article from Steve Cope](http://www.steves-internet-guide.com/using-lets-encrypt-certificate-mosquitto/) on using a LetsEncrypt certificate on Mosquitto.
- A [blog article by Besnik Belegu](https://medium.com/@besnikbelegu/enabling-tls-for-mosquitto-using-lets-encrypt-and-certbot-bf10bc863db) relating to the configuration of TLS for MQTT Mosquitto using LetsEncrypt and certbot.

Based on the articles above, the following method was derived to enable the use of a publically signed certificate for the MQTT server as setup by this repository. To follow the method below you will have to meet the following pre-requisites:

1. You are the owner of a domain and have access to DNS management for that domain. In this example we will use "example.co.uk"
2. You have exposed your MQTT broker through a URL based on the domain you own. So, in this example, you may have made your MQTT broker visible through "mqtt.example.co.uk". You will likely have done so, by creating a DNS A record mapping that name "mqtt.example.co.uk" to the IP or URL of the server hosting the broker.

#### Acquire a certificate

1. Log on to the Docker host. This is assumed to be an Ubuntu distribution. The key will be obtained by this machine and used by the MQTT server in the Docker machine to prove its identity.
2. Ensure the machine is up to date. Normally this would mean running commands like:
```
sudo apt update
sudo apt upgrade
```
3. Install certbot
```
sudo apt-get -y install certbot
```
4. Use Certbot to generate a certificate using the DNS Method. **NOTE: You will have to replace "mqtt.example.co.uk" in the command below with the name you have selected for your broker**
```
sudo certbot certonly --manual --preferred-challenge dns -d mqtt.example.co.uk
```
5. During the creation of the certificate you will be asked to generate a DNS TEXT record related to the name you have selected for your broker. This is to prove to Certbot that you have control and therefore own that domain.
6. On completion, you should receive a message something like the following, where mqtt.example.co.uk will be replaced with the domain name you selected for your broker and the expiry date will be different:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/mqtt.example.co.uk/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/mqtt.example.co.uk/privkey.pem
This certificate expires on 2026-07-26.
These files will be updated when the certificate renews.

NEXT STEPS:
- This certificate will not be renewed automatically. Autorenewal of --manual certificates requires the use of an authentication hook script (--manual-auth-hook) but one was not provided. To renew this certificate, repeat this same certbot command before the certificate's expiry date.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
``` 
7. The files mentioned in the messages above are actually links to the real files which are stored in the *archive* folder and not the *live* folder. There are also a couple of other files created that can be used. This is all discussed in the [Certbot manual](https://eff-certbot.readthedocs.io/en/stable/using.html#where-are-my-certificates). To avoid permissions problems copy those real files to the certs directory of our mqtt instance. **NOTE: Remember to change *mqtt.example.co.uk* to be the domain name you have used in both commands. The commands below assume you are running from inside the foler you checked out from Github.**
```
sudo cp /etc/letsencrypt/archive/mqtt.example.co.uk/fullchain1.pem certs/
sudo cp /etc/letsencrypt/archive/mqtt.example.co.uk/privkey1.pem certs/
```
8. Then change their ownership and permissions to make them useable by Mosquitto within the Docker machine.
```
sudo chown 1883:1883 certs/*.pem
```
9. Change the *mosquitto.conf* file to point to the relevant files.
```
sudo nano config/mosquitto.conf
```
10. After modification the *mosquitto.conf* file should contain the following around the defintiion of the port 8883 listener. Note that the cafile has been left at the generated file, meaning that if client authentication is turned on () then the generated client certificates should be used. Whilst the certificate file presented by the broker is the publically signed *fullchain1.pem* and the private key used by the broker in negotiating the encrypted channel with the client is in *privkey1.pem*:
```
# TLS listener on port 8883
listener 8883
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/fullchain1.pem
keyfile /mosquitto/certs/privkey1.pem
```
11. Finally restart the broker to start using the new details:
```
docker compose restart mosquitto
```
>[!WARNING]
>The certificates generated above will expire! The exprity date is given in the message you receive back from Certbot. You will need to rerun the same command before the expiry date to ensure that a valid certificate is available, you will also need to recopy the updated certificates to the certs folder as instructed above. A further update to this readme file will address how we can deal with expiring certificates.


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

