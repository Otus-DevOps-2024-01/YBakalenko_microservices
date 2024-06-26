# YBakalenko_micorservices

## Введение в Kubernetes #1 (kubernetes-1)
### Prepare system
1. Update system registry
   ```
   sudo apt update
   ```
2. Disable swap
   ```
   sudo swapoff -a
   sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
   ```
3. Setup overlay and netfilter
   ```
   sudo tee /etc/modules-load.d/containerd.conf <<EOF
   overlay
   br_netfilter
   EOF
   ```
   ```
   sudo modprobe overlay
   sudo modprobe br_netfilter
   ```
4. Set core parameters for Kubernetes:
   ```
   sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
   net.bridge.bridge-nf-call-ip6tables = 1
   net.bridge.bridge-nf-call-iptables = 1
   net.ipv4.ip_forward = 1
   EOF
   ```
   ```
   sudo sysctl --system
   ```
5. Add docker key and repo
   ```
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
   sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
   ```
6. Install necessary system components:
   ```
   sudo apt update
   sudo apt install -y curl software-properties-common apt-transport-https ca-certificates containerd.io gpg gnupg2
   ```
7. Setup containerd:
   ```
   containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
   sudo nano /etc/containerd/config.toml` and set `sandbox_image = "registry.k8s.io/pause:3.9"
   sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
   sudo systemctl restart containerd`
   sudo systemctl enable containerd`
   ```
8. Add Kubernetes key and repo:
   ```
   curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
   echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
   ```
9. Install kubeadm, kubectl
   ```
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm kubectl
   sudo apt-mark hold kubelet kubeadm kubectl
   ```
10. Check kubelet configuration:
   ```
   sudo nano /var/lib/kubelet/config.yaml` and enusre it contains `containerRuntimeEndpoint: unix:///run/containerd/containerd.sock
   sudo systemctl restart kubelet
   ```
### Установка роли master
1. Initialize the Kubernetes control-plane node (master)
   ```
   sudo kubeadm init --control-plane-endpoint=178.154.201.106 --pod-network-cidr=10.244.0.0/16 --apiserver-cert-extra-sans=178.154.201.106 --apiserver-advertise-address=0.0.0.0
   ```
2. To start using your cluster, you need to run the following as a regular user:
   ```
   mkdir -p $HOME/.kube
   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   sudo chown $(id -u):$(id -g) $HOME/.kube/config
   ```
3. Get container network interface config:
   ```
   curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O
   ```
4. Replace CALICO_IPV4POOL_CIDR value `192.168.0.0/16` to `10.244.0.0/16` and `image: docker` or `image: XXX` to `image: mirror.gcr.io`
   ```
   nano calico.yaml
   ```
5. Apply the manifest using the following command.
   ```
   kubectl apply -f calico.yaml
   ```
### Установка роли worker
1. Join node to cluster
   ```
   sudo kubeadm join 178.154.201.106:6443 --token w22flc.83t1skzsi8i360gn --discovery-token-ca-cert-hash sha256:332e8e7b83a12861c172c329782c35ecfc93c1a67a0a244ffa00e185f1454166
   ```
### Удаленное администрирование кластера Kubernetes
1. Copy the kubeconfig file from the master node to your local machine:
   ```
   scp ubuntu@178.154.201.106:/home/ubuntu/.kube/config ~/.kube/config
   ```
2. Set the KUBECONFIG environment variable to point to this file:
   ```
   export KUBECONFIG=~/.kube/config
   ```
3. Check nodes list:
   ```
   kubectl get nodes
   ```
