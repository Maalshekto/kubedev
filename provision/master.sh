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
CALICO_MANIFEST_URL="${CALICO_MANIFEST_URL}"
PROVISION_TIMEOUT="${PROVISION_TIMEOUT}"
PROVISION_JOIN_CMD_TTL="${PROVISION_JOIN_CMD_TTL}"
IP_MASTER="${IP_MASTER}"

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Update and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Docker installation
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

# Configure kubelet to use the correct IP address
sudo bash -c "echo 'KUBELET_EXTRA_ARGS=\"--node-ip=${IP_MASTER}\"' > /etc/default/kubelet"
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Initialize the Kubernetes cluster
sudo kubeadm init --apiserver-advertise-address ${IP_MASTER} --pod-network-cidr=${CLUSTER_CIDR} --upload-certs

# Copy the kubeconfig file to the vagrant user's home directory
sudo -u vagrant -i bash -c "
  mkdir -p /home/vagrant/.kube;
  sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config;
  sudo chown vagrant:vagrant /home/vagrant/.kube/config;   
"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

case "${CNI}" in 
  "calico")
    # Install Calico
    curl "${CALICO_MANIFEST_URL}" -O
    kubectl apply -f calico.yaml
    ;;

  "cilium")
    # Install Cilium
    sudo apt-get install -y iproute2
    CILIUM_CLI_VERSION=$(curl -s $CILIUM_LATEST_VERSION_URL)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/$CILIUM_CLI_VERSION/cilium-linux-$CLI_ARCH.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-$CLI_ARCH.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-$CLI_ARCH.tar.gz /usr/local/bin
    rm cilium-linux-$CLI_ARCH.tar.gz{,.sha256sum}
    cilium install --kubeconfig $HOME/.kube/config \
      --helm-set config.sourceIpVerification=false \
      --helm-set ipam.mode=cluster-pool \
      --helm-set ipam.operator.clusterPoolIPv4PodCIDRList={$CLUSTER_CIDR}
    ;;

  *)
    echo "[ERROR] No CNI specified"
    ;;
esac

# Wait for the master node to be ready
kubectl wait node $(hostname) --for=condition=Ready --timeout=${PROVISION_TIMEOUT}s
echo "Génération du token pour l'ajout des nœuds travailleurs..."
KUBEADM_JOIN_CMD=$(kubeadm token create --print-join-command --ttl ${PROVISION_JOIN_CMD_TTL})

# Save the join command to a file for the worker nodes
echo "$KUBEADM_JOIN_CMD" > /vagrant/join_command.sh
chmod +x /vagrant/join_command.sh