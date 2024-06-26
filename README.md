# YBakalenko_micorservices

## CI/CD в Kubernetes (kuberneets-4)
### Helm
1. Установил и настроил клиентскую часть Helm
   ```
   brew install helm
   ```
   Установился сразу Helm3, поэтому никаких дополнительных махинаций с Tiller и не потребовалось, т.к. он более не требуется
   Добавил стабильный репозиторий к Helm:
   ```
   helm repo add stable https://charts.helm.sh/stable
   ```
2. Создал стуктуру папок с чартами Helm для каождого из компонентов приложения в `kubernetes\Charts`, взяв за основу yml-манифесты деплойментов и сервисов Kubernetes соответствующих компонентов, заменив hard-coded имена на конструкции, использующие встроенные переменные Helm: `{{ .Release.Name }}, {{ .Chart.Name }}`
3. Определил пользовательские переменные в `values.yaml`-файлах и переопределил на них референсы на них в номерах портов, именах и тэгах образов контейнеров и адреса БД
4. Также отдельно получил удовольствие от переделки имен компонентов на замечательные Helper-функции, определенные в  `_helpers.tpl`-файлах
5. Создал общий верхнеуровневый Chart-проекта со своим `values.yaml`, переменные которого способны перезатирать значения нижеподчиненных компонент. А также добавил зависимости в виде самого образа mongo и определил его в `requirements.yaml`
### GitLab + Kubernetes
1. Создал новый класер k8s, забрал информацию о пользователе, кластере и контексте для управления:
   ```
   yc managed-kubernetes cluster get-credentials k8s-cluster --external
   ```
   Поставил `nginx ingress`:
   ```
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   ```
2. Развернул Gitlab в кластере вопреки инструкциям из ДЗ самым стандартным образом, используя гайд с [https://docs.gitlab.com/charts/quickstart/](https://docs.gitlab.com/charts/quickstart/)
 - Add Gitlab repo repository:
   ```
   helm repo add gitlab https://charts.gitlab.io
   ```
 - Install GitLab:
   ```
   helm install gitlab gitlab/gitlab \
   --set global.edition=ce \
   --set global.hosts.domain=example.com \
   --set global.ingress.configureCertmanager=false \
   --set certmanager.install=false \
   --set gitlab-runner.install=false
   ```
 - Retrieve the IP address:
   ```
   kubectl get ingress -lrelease=gitlab
   ```
 - Sign in to GitLab:
   ```
   kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo
   ```
 - Add a runner in Gitlab Admin Area and note a RegistrationToken
 - Deploy GitLab-runner using the RegistrationToken and Gitlab IP address, see [https://8grams.medium.com/how-to-setup-gitlab-runner-on-kubernetes-cluster-e4caf688ca89](https://8grams.medium.com/how-to-setup-gitlab-runner-on-kubernetes-cluster-e4caf688ca89):
   ```
   helm upgrade --install gitlab-runner gitlab/gitlab-runner -f gitlab-runner/values.yaml
   ```
3. Добавил в группу переменную CI_GITLAB_IP с IP-аресом хоста
4. Добавил 4 проекта (reddit-deploy, ui, post, comment) и свой SSH-ключ. Далее инициировал репо каждого компонента локально:
   ```
   cd existing_folder
   git init --initial-branch=main
   ```
   Add remote repo:
   ```
   git remote add origin git@gitlab.example.com:ybakalenko/<project_name>.git
   ```
   Or:
   ```
   git remote set-url origin https://gitlab.example.com/ybakalenko/<project_name>.git
   ```
   Then:
   ```
   git config http.sslVerify false
   git add .
   git commit -m "Initial commit"
   git push --set-upstream origin main
   ```
5. Добавил в каждый проект .gitlab-ci.yml со stages:
 - build
 - test
 - review
 - release
 - cleanup
6. Установил агента Gitlab в кластере Kubernetes, чтобы работали правил запуска/останова review ($CI_KUBERNETES == 'true'):
   ```
   helm upgrade --install kube-agent gitlab/gitlab-agent \
    --namespace gitlab-agent-kube-agent \
    --create-namespace \
    --set image.tag=v17.0.2 \
    --set config.token=glagent-XSsNpuSASrTmCyhk2sq5ny4LbzZYkCqwxi6H5n_kyDsACpe4-g \
    --set config.kasAddress=wss://kas.example.com \
    --set-file config.kasCaCert=gitlab-ca.pem \
    --set "hostAliases[0].ip=<ip_address>" \
    --set "hostAliases[0].hostnames[0]=kas.example.com"
   ```
7. Применил роль gitlab-runner/namespace-admin-role.yaml и привязал ее к сервисному аккаунту кластера
gitlab-runner/namespace-admin-binding.yaml, чтобы читать, создавать и удалять неймспейсы, сервисы, ингрессы и прочие сущности кубера из раннера
   ```
   kubectl apply -f gitlab-runner/namespace-admin-role.yaml
   kubectl apply -f gitlab-runner/namespace-admin-binding.yaml
   ```
8. Допилил `.gitlab-ci.yml` на основе `.auto_devops` так, чтобы не было deprecated команд, был helm3 и т.д. для проектов `ui`, `comment`, `post`, убедился, что все этапы работают корректно
9. Переделал `.gitlab-ci.yml`-ы с синтаксиста `.auto_devops` на синтаксис Gitlab, проверил на всех пайплайнах


## Ingress-контроллеры и сервисы в Kubernetes (kubernetes-3)
1. Поменял скейл для kube-dns и обнаружил, что он исчезает, вернул его на место
2. Поменял тип `ui-service` на `LoadBalancer`
3. Импортировал компонент для создания `IngressController`-а. Правильная команда всё же такая:
   ```
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
   ```
   В случае конфликтов с предыдущими версиями API выполнить:
   ```
   kubectl delete job ingress-nginx-admission-create -n ingress-nginx
   kubectl delete job ingress-nginx-admission-patch -n ingress-nginx
   ```
   Затем заново применить `deploy.yaml`
4. Добавил ui-ingress для доступа к `ui-service`
   Учел, что нужно в манифесте переходить на `apiVersion: networking.k8s.io/v1`, а также в спецификации указывать `ingressClassName: nginx`
5. Открыл список ingress-ов, посмотрел IP единственного доступного, открыл его в браузере, увидел работающее приложение
6. Далее подготовил сертификат используя IP как CN:
   ```
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=158.160.164.213"
   ```
   И загрузил сертификат в кластер kubernetes
7. Накатил сетевые политики `mongo-network-policy.yml`, чтобы в mongo ходили только `comment` и `post`
8. Создал диск для PersistentVolume хранилища в Yandex Cloud:
   ```
   yc compute disk create --name k8s --size 4 --description "disk for k8s"
   kubectl apply -f mongo-volume.yml
   ```
   Выделил PersistentVolumeClaim для нашего mongo:
   ```
   kubectl apply -f mongo-claim.yml`
   ```
   И пересоздал Deplyment mongo:
   ```
   kubectl delete deployment mongo -n dev`
   kubectl apply -f mongo-deployment.yml -n dev`
   ```
   Посты в базе остались на своем месте

## Основные модели безопасности и контроллеры в Kubernetes (kubernetes-2)

1. Установил локально `minikube`
2. Поднял и отладил в нем приложение
3. Создал кластер на Yandex Cloud. Получение информации о пользователе, кластере и контексте для управления:
   ```
   yc managed-kubernetes cluster get-credentials k8s-cluster --external
   ```
4. Поднял приложение в кластере на Yandex Cloud
5. Приложил (на всякий случай) картинку с web-интерфейсом:
   ![alt text](artifacts/reddit_app.png)

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

## Применение системы логирования в инфраструктуре на основе Docker (logging-1)
### Логирование Docker-контейнеров
1. Установка remote docker engine и подключение к нему через переменную среды
      ```
      export DOCKER_HOST=178.154.201.106
      ```
2. Подготовлены образы приожения с актуализированным кодом с файлом `docker-compose.yml` для деплоя
   приложения с драйвером сбора логов fluentd, а также трейсов zipkin. Запуск контейнеров приложения:
      ```
      export USER_NAME=ybakalenko
      cd ./src/ui && bash docker_build.sh && docker push $USER_NAME/ui
      cd ../post-py && bash docker_build.sh && docker push $USER_NAME/post
      cd ../comment && bash docker_build.sh && docker push $USER_NAME/comment
      ```
   Запуск контейнеров приложения:
      ```
      docker compose up -d
      ```
### Cбор структурированных логов
1. Подготовка образа плагина fluentd для сбора логов приложения на основе `Dockerfile`:
      ```
      cd logging/fluentd
      docker build -t $USER_NAME/fluentd .
      ```
2. Создан экземпляр Elastic Stack наиболее свежей версии 8.13.4 на основе `docker-compose` файла для
   сервисов логгирования. Запуск контейнеров компонентов Elastic Stack:
      ```
      docker compose -f docker-compose-logging.yml up -d
      ```
### Работа с визуализацией Elastic stack
1. Поиск и фильтрация по полям записей в централизованной базе логов Elasticsearch (KQL)
   Как получить Elasticsearch enrollment token:
      ```
      docker exec -it docker-elasticsearch-1 /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
      ```
   Как получить OTP для аутентификации в Kibana:
      ```
      docker exec -it docker-kibana-1 bin/kibana-verification-code
      ```
   Сброс пароля пользователя elastic:
      ```
      docker exec -it docker-elasticsearch-1 bin/elasticsearch-reset-password -u elastic
      ```
2. Настройка парсера логов формата JSON (`fluentd.conf`)
### Сбор неструктурированных логов
1. Настройка парсера логов через RegEx (`fluentd.conf`)
2. Настройка парсера логов формата RUBY (`fluentd.conf`)
3. Настройка grok-парсера логов формата (`fluentd.conf`)
4. Настройка нескольких парсеров одновременно (`fluentd.conf`)
### Распределенный трейсинг
1. Настройка сервера сбора трейсов Zipkin в составе сервисов логгирования (`docker-compose-logging.yml`)
2. Работа с UI приложения и анализ спанов, входящих в HTTP-трейсы приложения

## Введение в мониторинг. Системы мониторинга. (monitoring-1)
1. Запуск docker-контейнера `Prometheus`
2. Настройка таргетов `Prometheus` для сбора метрик и мониторинга состояния микросеврсиов
3. Настройка Exporter-а для сбора метрик с хоста docker engine (`Node exporter`)
4. Образы `comment`, `post`, `ui`, `prometheus` запушены в репозиторий:
   https://hub.docker.com/repositories/ybakalenko

## Cети, docker-compose (docker-4)
1. Запуск контейнеров в различных сетевых пространствах с использованием драйверов {`host`, `bridge`, `none`}
2. Создание виртуальных сетей контейнеров и запуск/подключение контейнеров компонентов приложения в этих сетях
3. Запуск контейнеров приложения с применением docker-compose
   - Адаптация `docker-compose` под кейс с множеством сетей, сетевых алиасов
   - Параметризация `docker-compose` с использованием файла `.env`
   - Cоздаваемые docker-compose сущности имеют одинаковый префикс по имени директории проекта, где размещен файл `docker-compose.yml`, к примеру `src-ui-1`

## Docker-образы. Микросервисы (docker-3)
1. Описание и сборка образов для компонентов приложения через  `Dockerfile`.
2. Оптимизация инструкций `Dockerfile` для снижения объема, занимаемого образом, следуя рекомендуемым практикам в
   написании `Dockerfile` и пользуясь линтером.
3. Запуск контейнеров из созданных образов в bridge-сети с использованием сетевых алиасов контейнеров.

## Технология контейнеризации. Введение в Docker (docker-2)
1. Установка Docker
2. Создание VM в Yandex Clound для Docker engine через Yandex Client CLI
3. Настройка удаленного Docker engine daemon на базе виртуальной машины в Yandex Cloud
   Т.к. в современной сборке Docker отсутствует `docker-machine`, установка Docker engine  виртуальной машине выполнена вручную, а для работы с удаленным  Docker engine применялась команда `export DOCKER_HOST=Remote_IP:2375`
4. Создание образа ВМ с предустановленным MongoDB, Ruby и приложением Reddit на удаленном Docker engine через
   `Dockerfile`
5. Загрузка образа Docker на Docker hub и локальное создание контейнера из образа, полученного из Docker hub
