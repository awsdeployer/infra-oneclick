#!/bin/bash
# Exit on any error
set -e
sudo hostnamectl set-hostname master
echo "===== Installing Docker ====="
# Remove old versions
sudo apt remove -y docker docker-engine docker.io containerd runc || true
# Install Docker
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
# Add current user to docker group
sudo groupadd -f docker
sudo usermod -aG docker $USER
newgrp docker || true
echo "=======kubeadm initializing========"
sudo kubeadm init --cri-socket=unix:///var/run/crio/crio.sock
echo "===== Setting up kubeconfig for current user ====="
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "===== Deploying Weave Net pod network ====="
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
echo "===== Untainting control-plane node so pods can run on it ====="
kubectl taint node $(hostname) node-role.kubernetes.io/control-plane:NoSchedule- || true
echo "Waiting for kube-system pods to be Ready..."
until kubectl get pods -n kube-system | grep -Ev 'STATUS|Running' | wc -l | grep -q '^0$'; do
    sleep 5
done
echo "Kubernetes control-plane setup complete."
echo "Kubernetes ingress setup."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
echo "Kubernetes metrics-server setup"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

