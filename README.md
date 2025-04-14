# Local Deploy

## Install Kind cluster
```bash
kind create cluster --config res/kind-config.yaml
```

## Add Helm repos
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add metallb https://metallb.github.io/metallb
helm repo update
```

## Install CNI

Get Cilium CLI:
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

Install Cilium:
```bash
cilium install --version 1.17.2 --wait
```

## Install Nginx Ingress
```bash
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set-string controller.metrics.serviceMonitor.additionalLabels.release="prometheus" \
  --set-string controller.podAnnotations."prometheus\.io/scrape"="true" \
  --set-string controller.podAnnotations."prometheus\.io/port"="10254"
```

## Install Load Balancer
```bash
helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system --create-namespace
```
Apply the config:
```bash
./set_ip_addr.sh
kubectl apply -f res/metallb.yaml
```

Check if Nginx external IP has been assigne:
```bash
kubectl get svc -n ingress-nginx
```
In case it has not you can try manually assigning it:
```bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"loadBalancerIP": "<an_ip_in_the_range>"}}'
```

## Install Prometheus, AlertMananger, Grafana
```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminUser='admin' \
  --set grafana.adminPassword='password' \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.service.type=LoadBalancer \
  --set alertmanager.service.type=LoadBalancer \
  --set prometheus.service.port=80 \
  --set prometheus.service.targetPort=9090 \
  --set alertmanager.service.port=80 \
  --set alertmanager.service.targetPort=9093 \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

All services should be up and running:
```bash
kubectl get svc -n monitoring
```

As soon as you access first time the ingress (e.g. `curl http://<nginx_ip>/`) you should see some metrics exposed in the Prometheus UI.