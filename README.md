# Kubernetes Cluster with Vagrant

This repository provides a simple setup to deploy a Kubernetes cluster using Vagrant and VirtualBox. The cluster consists of one master node and multiple worker nodes.

## Prerequisites

Ensure your host machine has the following software installed:

1. **Vagrant** (version 2.2.0 or higher)
   - [Download Vagrant](https://www.vagrantup.com/downloads)

2. **VirtualBox** (version 6.1 or higher)
   - [Download VirtualBox](https://www.virtualbox.org/wiki/Downloads)

3. **Git** (optional, for cloning the repository)
   - [Download Git](https://git-scm.com/downloads)

4. **Internet Connection**
   - Required for downloading base boxes and provisioning dependencies.

### Host Machine Requirements

- **Operating System:** Windows, macOS, or Linux
- **Memory:** At least 8 GB RAM (16 recommended)
- **CPU:** Multi-core processor (8 hyperthreaded cores recommended)
- **Disk Space:** Minimum 50 GB free space to accommodate virtual machines and Docker/Kubernetes components.

## Setup and Usage

1. **Clone the Repository**

   ```bash
   git clone https://github.com/yourusername/kubedev.git
   cd kubedev
   ```
Configure Parameters (Optional)

Edit the config.yml file to customize IP addresses, memory, CPU allocations, and the number of worker nodes as needed.
Start the Cluster

Run the following command to initialize and provision the Kubernetes cluster:

bash
Copier le code
vagrant up
This command will create and configure the master and worker nodes based on the provided Vagrantfile and config.yml.
Accessing the Cluster
SSH into the Master Node

bash
Copier le code
vagrant ssh controlplane
Verify Kubernetes is Running

Once inside the master node, check the status of the nodes and pods:

bash
Copier le code
kubectl get nodes
kubectl get pods --all-namespaces
You should see the master node and all worker nodes listed as Ready.
Kubernetes system pods should be in the Running state.
Testing the Cluster
To ensure your Kubernetes cluster is functioning correctly, you can deploy a simple application:

Deploy a Sample Application

bash
Copier le code
kubectl create deployment hello-node --image=k8s.gcr.io/echoserver:1.4
kubectl expose deployment hello-node --type=NodePort --port=8080
Retrieve the Service URL

bash
Copier le code
kubectl get services hello-node
Note the NodePort assigned to the service (e.g., 30007).
Access the Application

Open a web browser and navigate to http://<master_ip>:<NodePort>, for example:

arduino
Copier le code
http://192.168.100.10:30007
You should see a response from the hello-node application, confirming that the cluster is operational.
Stopping the Cluster
To stop all running Vagrant machines without destroying them:

bash
Copier le code
vagrant halt
Destroying the Cluster
To remove all Vagrant machines and associated resources:

bash
Copier le code
vagrant destroy -f
Note: This action is irreversible and will delete all data on the virtual machines.

Troubleshooting
DNS Resolution Issues:

Ensure your host machine has a stable internet connection.
Disable VPNs or firewalls that might block DNS queries.
Provisioning Failures:

Re-run vagrant up to retry provisioning.
Check logs by SSHing into the affected node and inspecting service logs (e.g., Docker, kubelet).
Kubernetes Components Not Ready:

Verify that all nodes are listed as Ready using kubectl get nodes.
Ensure sufficient resources (CPU, RAM) are allocated to each VM.
License
This project is licensed under the MIT License.

Disclaimer: This setup is intended for development and testing purposes. For production environments, consider using more robust deployment methods and following Kubernetes best practices.
