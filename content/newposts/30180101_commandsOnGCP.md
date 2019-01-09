+++
title = "Summaries of some of the sessions in React Conference 2018"
description = "Summaries of some of the sessions in React Conference 2018"
tags = [
    "google cloud platform",
]
date = "3018-05-02"
categories = [
    "google cloud platform",
]
+++

## Random commands

```
sed -i -e 's/webapp2/webapp22/' main.py
```

## Google App Engine

```
dev_appserver.py {directory}
gcloud app deploy app.yaml

```

## Google Compute Management

```
gcloud compute instances create "nginxstack-1" \
  --machine-type "f1-micro" \
  --tags nginxstack-tcp-443,nginxstack-tcp-80 \
  --zone us-central1-f \
  --image   "https://www.googleapis.com/compute/v1/projects/bitnami-launchpad/global/images/bitnami-nginx-1-14-0-4-linux-debian-9-x86-64" \
  --boot-disk-size "200" --boot-disk-type "pd-standard" \
  --boot-disk-device-name "nginxstack-1"

gcloud compute instances create webserver4 \
    --image-family debian-9 \
    --image-project debian-cloud \
    --tags int-lb \
    --zone $MY_ZONE2 \
    --subnet default \
    --metadata startup-script-url="gs://cloud-training/archinfra/mystartupscript",my-server-id="WebServer-4"

gcloud compute instance-groups unmanaged create ig1 \
    --zone $MY_ZONE1

gcloud compute instance-groups unmanaged add-instances ig1 \
    --instances=webserver2,webserver3 --zone $MY_ZONE1

gcloud compute health-checks create tcp my-tcp-health-check \
    --port 80

gcloud compute backend-services create my-int-lb \
    --load-balancing-scheme internal \
    --region $MY_REGION \
    --health-checks my-tcp-health-check \
    --protocol tcp

# Part of creating a pool of compute instances
gcloud compute target-pools create extloadbalancer \
    --region $MY_REGION --http-health-check webserver-health

gcloud compute target-pools add-instances extloadbalancer \
    --instances webserver1,webserver2,webserver3 \
     --instances-zone=$MY_ZONE1

gcloud compute forwarding-rules create webserver-rule \
    --region $MY_REGION --ports 80 \
    --address $STATIC_EXTERNAL_IP --target-pool extloadbalancer
```

## Google Networking commands

```
gcloud compute firewall-rules create nginx-firewall \
 --allow tcp:80,tcp:443 \
 --target-tags nginxstack-tcp-80,nginxstack-tcp-443


gcloud compute target-vpn-gateways \
create vpn-1 \
--network vpn-network-1  \
--region us-east1

gcloud compute addresses create --region us-east1 vpn-1-static-ip

gcloud compute addresses list

# ESP protocol - encapsulated security protocol
gcloud compute \
forwarding-rules create vpn-1-esp \
--region us-east1  \
--ip-protocol ESP  \
--address $STATIC_IP_VPN_1 \
--target-vpn-gateway vpn-1

gcloud compute \
forwarding-rules create vpn-1-udp500  \
--region us-east1 \
--ip-protocol UDP \
--ports 500 \
--address $STATIC_IP_VPN_1 \
--target-vpn-gateway vpn-1

gcloud compute target-vpn-gateways list

gcloud compute \
vpn-tunnels create tunnel1to2  \
--peer-address $STATIC_IP_VPN_2 \
--region us-east1 \
--ike-version 2 \
--shared-secret gcprocks \
--target-vpn-gateway vpn-1 \
--local-traffic-selector 0.0.0.0/0 \
--remote-traffic-selector 0.0.0.0/0

gcloud compute \
vpn-tunnels create tunnel2to1 \
--peer-address $STATIC_IP_VPN_1 \
--region europe-west1 \
--ike-version 2 \
--shared-secret gcprocks \
--target-vpn-gateway vpn-2 \
--local-traffic-selector 0.0.0.0/0 \
--remote-traffic-selector 0.0.0.0/0
```

## Managing a cluster on GKE

```
gcloud container clusters create networklb --num-nodes 3
kubectl run nginx --image=nginx --replicas=3
kubectl get pods -owide
kubectl expose deployment nginx --port=80 --target-port=80 --type=LoadBalancer
kubectl get service nginx

kubectl delete service nginx
kubectl delete deployment nginx
gcloud container clusters delete networklb
```

```
gcloud container clusters create $CLUSTER_NAME --zone $MY_ZONE
kubectl run nginx --image=nginx --port=80
kubectl expose deployment nginx --target-port=80 --type=NodePort
kubectl create -f basic-ingress.yaml
kubectl get ingress basic-ingress --watch
kubectl describe ingress basic-ingress
kubectl get ingress basic-ingress
```

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: basic-ingress
spec:
  backend:
    serviceName: nginx
    servicePort: 80
```
