## Применение системы логирования в инфраструктуре на основе Docker

### Логирование Docker-контейнеров
1. Установка remote docker engine и подключение к нему через переменную среды
      `export DOCKER_HOST=178.154.201.106`
2. Подготовлены образы приожения с актуализированным кодом с файлом `docker-compose.yml` для деплоя
   приложения с драйвером сбора логов fluentd, а также трейсов zipkin. Запуск контейнеров приложения:
      `export USER_NAME=ybakalenko`
      `cd ./src/ui && bash docker_build.sh && docker push $USER_NAME/ui`
      `cd ../post-py && bash docker_build.sh && docker push $USER_NAME/post`
      `cd ../comment && bash docker_build.sh && docker push $USER_NAME/comment`
   Запуск контейнеров приложения:
      `docker compose up -d`

### Cбор структурированных логов
1. Подготовка образа плагина fluentd для сбора логов приложения на основе `Dockerfile`:
      `cd logging/fluentd`
      `docker build -t $USER_NAME/fluentd .`
2. Создан экземпляр Elastic Stack наиболее свежей версии 8.13.4 на основе `docker-compose` файла для
   сервисов логгирования. Запуск контейнеров компонентов Elastic Stack:
      `docker compose -f docker-compose-logging.yml up -d`

### Работа с визуализацией Elastic stack
1. Поиск и фильтрация по полям записей в централизованной базе логов Elasticsearch (KQL)
   Как получить Elasticsearch enrollment token:
      `docker exec -it docker-elasticsearch-1 /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana`
   Как получить OTP для аутентификации в Kibana:
      `docker exec -it docker-kibana-1 bin/kibana-verification-code`
   Сброс пароля пользователя elastic:
      `docker exec -it docker-elasticsearch-1 bin/elasticsearch-reset-password -u elastic`
2. Настройка парсера логов формата JSON (`fluentd.conf`)

### Сбор неструктурированных логов
1. Настройка парсера логов через RegEx (`fluentd.conf`)
2. Настройка парсера логов формата RUBY (`fluentd.conf`)
3. Настройка grok-парсера логов формата (`fluentd.conf`)
4. Настройка нескольких парсеров одновременно (`fluentd.conf`)

### Распределенный трейсинг
1. Настройка сервера сбора трейсов Zipkin в составе сервисов логгирования (`docker-compose-logging.yml`)
2. Работа с UI приложения и анализ спанов, входящих в HTTP-трейсы приложения
