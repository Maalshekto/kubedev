# -*- mode: ruby -*-
# vi:set ft=ruby sw=2 ts=2 sts=2:

require 'yaml'

# Load configuration from config.yml
config_file = File.join(__dir__, 'config.yml')
abort("config.yml file not found !") unless File.exist?(config_file)
config_data = YAML.load_file(config_file)

# Assign configuration settings to variables
BUILD_MODE = config_data['build_mode']
PRIVATE_IP_PREFIX = config_data['private_ip_prefix']
CLUSTER_CIDR = config_data['cluster_cidr']
IP_MASTER_SUFFIX = config_data['ip_master_suffix']
IP_WORKER_SUFFIX = config_data['ip_worker_suffix']
NUM_WORKERS = config_data['num_workers']
MASTER_CONFIG = config_data['master']
WORKERS_CONFIG = config_data['workers']
DOCKER_CONFIG = config_data['docker']
KUBERNETES_CONFIG = config_data['kubernetes']
PROVISION_CONFIG = config_data['provision']

# Function to check if DNS is blocked
def check_dns_blockage
  if Vagrant::Util::Platform.windows?
    check_dns_windows
  elsif Vagrant::Util::Platform.linux? || Vagrant::Util::Platform.darwin?
    check_dns_unix
  else
    raise "Unsupported platform"
  end
end

# Function to check DNS resolution on Windows
def check_dns_windows
  begin
    puts "Checking DNS resolution..."
    nslookup_output = `nslookup google.com 8.8.8.8 2>&1`
    if nslookup_output.include?("timed out")
      abort <<-MSG
[ERROR] DNS resolution is not working properly. Please check your network settings.
If you are using a VPN, you may need to disable it and execute `vagrant up` again.	
MSG
    end
  rescue => e
    abort "Error: Impossible to test DNS resolution using nslookup. Details: #{e.message}"
  end
end

# Function to check DNS resolution on Linux and macOS
def check_dns_unix
  begin
    puts "Checking DNS resolution..."
    dig_output = `dig +short google.com @8.8.8.8`
    if dig_output.strip.empty?
      abort <<-MSG 
[ERROR] DNS resolution is not working properly. Please check your network settings.
If you are using a VPN, you may need to disable it and execute `vagrant up` again.	
MSG
    end
  rescue => e
    abort "Error: Impossible to test DNS resolution using nslookup. Details: #{e.message}"
  end
end

Vagrant.configure("2") do |config|

  # Check DNS blockage when running 'vagrant up'
  if ARGV.include?("up")
    check_dns_blockage
  end

  # Define the base box and provider settings
  config.vm.box = "ubuntu/focal64"

  # Settle the provider settings
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 2
  end

  # Settings for the control plane node
  config.vm.define "controlplane" do |master|
    master.vm.hostname = MASTER_CONFIG['hostname']
    master.vm.provider "virtualbox" do |vb|
      vb.memory = MASTER_CONFIG['memory']
      vb.cpus = MASTER_CONFIG['cpus']
      vb.name = MASTER_CONFIG['name']
      vb.customize ["modifyvm", :id, "--natdnsproxy1", MASTER_CONFIG['natdnsproxy'] ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", MASTER_CONFIG['natdnshostresolver'] ? "on" : "off"]
    end

    if BUILD_MODE == "BRIDGE"
      master.vm.network :public_network, bridge: MASTER_CONFIG['public_network_bridge'], ip: "192.168.1.35"
    else
      master.vm.network :private_network, ip: "#{PRIVATE_IP_PREFIX}.#{IP_MASTER_SUFFIX}"
      master.vm.network "forwarded_port", guest: MASTER_CONFIG['forwarded_ports']['ssh_guest'], host: MASTER_CONFIG['forwarded_ports']['ssh_host_start']
    end

    # Provisioning with a separate script
    master.vm.provision "file", source: "provision/master.sh", destination: "/tmp/master.sh"
    master.vm.provision "shell", inline: <<-SHELL
      chmod +x /tmp/master.sh
      IP_MASTER=#{PRIVATE_IP_PREFIX}.#{IP_MASTER_SUFFIX} CLUSTER_CIDR=#{CLUSTER_CIDR} \
      DOCKER_GPG_URL=#{DOCKER_CONFIG['gpg_url']} DOCKER_REPO_URL=#{DOCKER_CONFIG['repo_url']} \
      DOCKER_REPO_DISTRIBUTION=#{DOCKER_CONFIG['repo_distribution']} DOCKER_REPO_COMPONENT=#{DOCKER_CONFIG['repo_component']} \
      KUBERNETES_GPG_URL=#{KUBERNETES_CONFIG['gpg_url']} KUBERNETES_REPO_URL=#{KUBERNETES_CONFIG['repo_url']} \
      KUBERNETES_REPO_DISTRIBUTION=#{KUBERNETES_CONFIG['repo_distribution']} KUBERNETES_REPO_COMPONENT=#{KUBERNETES_CONFIG['repo_component']} \
      CLUSTER_CIDR=#{CLUSTER_CIDR} CALICO_MANIFEST_URL=#{KUBERNETES_CONFIG['calico_manifest_url']} \
      PROVISION_TIMEOUT=#{PROVISION_CONFIG['timeout']} PROVISION_JOIN_CMD_TTL=#{PROVISION_CONFIG['join_cmd_ttl']} \
      /tmp/master.sh
    SHELL
  end

  # Settings for the worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "worker#{i}" do |worker|
      worker.vm.hostname = "#{WORKERS_CONFIG['base_hostname']}#{i}"
      worker.vm.provider "virtualbox" do |vb|
        vb.memory = WORKERS_CONFIG['memory']
        vb.cpus = WORKERS_CONFIG['cpus']
        vb.name = "#{WORKERS_CONFIG['base_hostname']}#{i}"
        vb.customize ["modifyvm", :id, "--natdnsproxy1", WORKERS_CONFIG['natdnsproxy'] ? "on" : "off"]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", WORKERS_CONFIG['natdnshostresolver'] ? "on" : "off"]
      end

      if BUILD_MODE == "BRIDGE"
        worker.vm.network :public_network, bridge: WORKERS_CONFIG['public_network_bridge'], ip: "192.168.1.#{20 + i}"
      else
        worker.vm.network :private_network, ip: "#{PRIVATE_IP_PREFIX}.#{IP_WORKER_SUFFIX + i - 1}"
        worker.vm.network "forwarded_port", guest: WORKERS_CONFIG['forwarded_ports']['ssh_guest'], host: WORKERS_CONFIG['forwarded_ports']['ssh_host_start'] + (i - 1)
      end

      # Provisioning with a separate script
      worker.vm.provision "file", source: "provision/worker.sh", destination: "/tmp/worker.sh"
      worker.vm.provision "shell", inline: <<-SHELL
        chmod +x /tmp/worker.sh
        IP_NODE=#{PRIVATE_IP_PREFIX}.#{IP_WORKER_SUFFIX + i - 1} IP_MASTER=#{PRIVATE_IP_PREFIX}.#{IP_MASTER_SUFFIX} \
        DOCKER_GPG_URL=#{DOCKER_CONFIG['gpg_url']} DOCKER_REPO_URL=#{DOCKER_CONFIG['repo_url']} \
        DOCKER_REPO_DISTRIBUTION=#{DOCKER_CONFIG['repo_distribution']} DOCKER_REPO_COMPONENT=#{DOCKER_CONFIG['repo_component']} \
        KUBERNETES_GPG_URL=#{KUBERNETES_CONFIG['gpg_url']} KUBERNETES_REPO_URL=#{KUBERNETES_CONFIG['repo_url']} \
        KUBERNETES_REPO_DISTRIBUTION=#{KUBERNETES_CONFIG['repo_distribution']} KUBERNETES_REPO_COMPONENT=#{KUBERNETES_CONFIG['repo_component']} \
        CLUSTER_CIDR=#{CLUSTER_CIDR} PROVISION_TIMEOUT=#{PROVISION_CONFIG['timeout']} \
        /tmp/worker.sh
      SHELL
    end
  end
end
