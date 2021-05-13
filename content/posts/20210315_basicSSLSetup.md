+++
title = "Basic SSL Setup"
description = "Basic SSL Setup - a note to self when setting up SSL certificates in the future"
tags = [
    "nginx",
]
date = "2021-03-15"
categories = [
    "nginx",
]
+++

Install nginx on the instance. We would also probably need to install vim as well to make it changes on nginx configuration.

```bash
sudo apt update && sudo apt install -y nginx vim
sudo su
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl
```

Create the following file in `ca.config`. The following ca configuration is used to create and configure SSL certifications

```
[ ca ]
# `man ca`
default_ca = CA_default

[ CA_default ]
copy_extensions = copy 

[req]
distinguished_name = req_distinguished_name
x509_extensions     = server_cert
req_extensions = server_cert

[req_distinguished_name]
commonName             = commonname

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
# Extensions for server certificates (`man x509v3_config`).
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
#authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName          = @alternate_names

[ alternate_names ]
DNS.1       = localhost
DNS.2       = lol.testtest.com
```

Refer to documentation for more details:  
https://jamielinux.com/docs/openssl-certificate-authority/create-the-root-pair.html

```bash
openssl genrsa -out ca.key 2048
openssl rsa -in ca.key -pubout > ca.pub

# Certificate "request" but produces a self signed cert instead
openssl req -x509 -config ca.config -new -nodes -key ca.key -sha256 -days 365 -out ca.pem -extensions v3_ca
```

Create server SSL certificate

```bash
openssl genrsa -out dev.app.key.server 2048

# Certificate "request"
# In order to make it easier - use *.example.com for common name
openssl req -new -key dev.app.key.server -out dev.app.csr

openssl x509 -req -in dev.app.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out dev.app.crt.server -days 365 -sha256 -extfile ca.config -extensions server_cert

cp dev.app.crt.server dev.app.crt
cat ca.pem  >> dev.app.crt
cp dev.app.key.server dev.key.crt
cat ca.key  >> dev.key.crt
```

With that, edit nginx accordingly to allow ssl traffic on the following file `/etc/nginx/sites-available/default`. Ensure one of the blog have https port, 443 be allowed with ssl and to have the ssl certificate and ssl certificate that we created used here

```
server {
  listen 443 ssl default_server;
  ssl_certificate     /etc/nginx/ssl/dev.app.crt;
  ssl_certificate_key /etc/nginx/ssl/dev.key.crt;
  ...
}
```

We can go into another VM instance on Google Compute Engine and try to curl it to the server instance. Copy over the `ca.pem` over from the server. Google Cloud instances 

```bash
curl --cacert ca.pem https://instance-1
```

We would get the following error

```
curl: (60) SSL: no alternative certificate subject name matches target host name 'instance-1'
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

Note from above that only 2 domains is acceptable: `localhost` and `lol.testtest.com`. Add ip address of the server with the `lol.testtest.com` domain to the `/etc/hosts` file.

We can then use curl on domains specified in the SSL Cert - `lol.testtest.com` to obtain the response accordingly.

```bash
curl --cacert ca.pem https://lol.testtest.com
```

Create client SSL certificate request. We need to pass the certificate request to the instance that has the ca certificate to sign it

```bash
openssl genpkey -algorithm RSA -out client.key -pkeyopt rsa_keygen_bits:2048

openssl req -new -key client.key -out client.req -subj /CN=testtest
```

Sign it and put it back to the caller instance

```bash
openssl x509 -req -in client.req -CA ca.pem -CAkey ca.key -set_serial 101 -extensions client -days 365 -sha256 -outform PEM -out client.crt

openssl x509 -in client.crt -noout -text
```

Adjust nginx configuration - `/etc/nginx/nginx.conf`

```
http {
        
        map $ssl_client_s_dn $allowed {
          default no;
          "CN=testtest" yes;
        }

        ...
```

Adjust the following nginx configuration - `/etc/nginx/sites-available/default`

```
server {
        ...

        listen 443 ssl default_server;
        ssl_certificate        /etc/nginx/ssl/dev.app.crt;
        ssl_certificate_key    /etc/nginx/ssl/dev.key.crt;
        ssl_verify_client      on;
        ssl_client_certificate /etc/nginx/ssl/ca.pem;
         
        if ($allowed = "no") {
          return 403;
        }

        ...
```

We can run curl request

```bash
curl --cacert ca.pem https://lol.testtest.com
```

But we would receive the following response though

```
<html>
<head><title>400 No required SSL certificate was sent</title></head>
<body bgcolor="white">
<center><h1>400 Bad Request</h1></center>
<center>No required SSL certificate was sent</center>
<hr><center>nginx/1.14.2</center>
</body>
</html>
```

We would need to pass the client ssl certificates

```bash
curl --cacert ca.pem --cert client.crt --key client.key  https://lol.testtest.com
```