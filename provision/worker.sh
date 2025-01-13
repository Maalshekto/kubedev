#!/bin/bash
set -e

# Use the environment variables passed by Vagrant
DOCKER_GPG_URL="${DOCKER_GPG_URL}"
DOCKER_REPO_URL="${DOCKER_REPO_URL}"
DOCKER_REPO_DISTRIBUTION="${DOCKER_REPO_DISTRIBUTION}"
DOCKER_REPO_COMPONENT="${DOCKER_REPO_COMPONENT}"
KUBERNETES_GPG_URL="${KUBERNETES_GPG_URL}"
KUBERNETES_REPO_URL="${KUBERNETES_REPO_URL}"
KUBERNETES_REPO_DISTRIBUTION="${KUBERNETES_REPO_DISTRIBUTION}"
KUBERNETES_REPO_COMPONENT="${KUBERNETES_REPO_COMPONENT}"
CLUSTER_CIDR="${CLUSTER_CIDR}"
PROVISION_TIMEOUT="${PROVISION_TIMEOUT}"
IP_NODE="${IP_NODE}"
IP_MASTER="${IP_MASTER}"

# Update and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Install Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL "${DOCKER_GPG_URL}" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] ${DOCKER_REPO_URL} ${DOCKER_REPO_DISTRIBUTION} ${DOCKER_REPO_COMPONENT}" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

# containerd configuration
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml
sudo systemctl restart containerd

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

# Install Kubernetes
sudo curl -fsSL "${KUBERNETES_GPG_URL}" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] ${KUBERNETES_REPO_URL} ${KUBERNETES_REPO_DISTRIBUTION} ${KUBERNETES_REPO_COMPONENT}" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# configure kubelet to use the correct IP address
sudo bash -c "echo 'KUBELET_EXTRA_ARGS=\"--node-ip=${IP_NODE}\"' > /etc/default/kubelet"
sudo systemctl daemon-reload
sudo systemctl restart kubelet

echo "Worker node: waiting for join command..."

TIMEOUT=${PROVISION_TIMEOUT}
INTERVAL=5
START=$(date +%s)

# Wait for the join command file to be available
while [ ! -f /vagrant/join_command.sh ]; do
  CURRENT=$(date +%s)
  ELAPSED=$(( CURRENT - START ))

  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Timeout - ${PROVISION_TIMEOUT} seconds. Canceling join command retrieval."
    exit 1
  fi
  echo "Join command file not found, waiting..."
  sleep $INTERVAL
done

echo "Join command file found, executing join command..."
echo "Worker node: waiting for master to be ready..."

START=$(date +%s)

# Attendre que le maître soit prêt
until nc -z ${IP_MASTER} 6443; do
  CURRENT=$(date +%s)
  ELAPSED=$(( CURRENT - START ))

  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "Timeout - ${PROVISION_TIMEOUT} seconds. Master is not ready yet. Canceling."
    exit 1
  fi
  echo "Master not ready, waiting..."
  sleep $INTERVAL
done
echo "Master is ready, executing join command..."
sh /vagrant/join_command.sh