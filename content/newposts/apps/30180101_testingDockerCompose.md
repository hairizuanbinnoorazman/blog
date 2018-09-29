Debian installation of docker

```bash
sudo apt update
sudo apt-get -y install \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get -y install docker-ce
sudo usermod -aG docker {user}
```

Ubuntu installation of docker

```bash
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install docker-ce
sudo usermod -aG docker {user}
```

Select one of them to be as master - the rest would be worker nodes.
The images will be deployed across both master and worker respectively

On master

```bash
docker swarm init --advertise-addr {master ip address}
```

On worker

```bash
docker swarm join --token {some-token} {master ip address}:2377
```

```bash
docker service create --mode=global --publish published=80,target=80 nginx
docker service rm {service name}
docker service create --name test --publish published=80,target=80 --replicas=3 nginx
# Only works as an ingress per say... can only curl manager node
```
