# SoulTips Nginx Configuration

Конфигурация nginx для проекта SoulTips с автоматическим развертыванием через GitHub Actions.

## Архитектура

- **Frontend**: Статические файлы собираются в Docker volume `frontend_dist`
- **Nginx**: Обслуживает статические файлы и проксирует API запросы к backend
- **Backend**: Работает отдельно в той же Docker сети `soultips_network`
- **TLS**: Настраивается вручную с помощью Let's Encrypt

## Настройка сервера

### 1. Ручная подготовка сервера

Выполните следующие шаги на сервере под admin пользователем (root/admin):

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl start docker
sudo systemctl enable docker

# Установка Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Создание пользователя deploy
sudo useradd -m -s /bin/bash deploy
sudo passwd deploy  # Установите пароль для deploy пользователя

# Добавление deploy в группу docker
sudo usermod -aG docker deploy

# Создание рабочей директории
sudo mkdir -p /opt/soultips/
sudo chown -R deploy:deploy /opt/soultips/

# Перезапуск Docker для применения изменений групп
sudo systemctl restart docker

# Проверка доступа deploy к Docker
sudo -u deploy docker --version
sudo -u deploy docker-compose --version
```

### 2. Настройка GitHub Secrets

Добавьте следующие секреты в настройки репозитория:

- `HOST` - IP адрес или домен сервера
- `USERNAME` - **deploy** (только пользователь deploy)
- `PASSWORD` - пароль пользователя deploy
- `PORT` - SSH порт (обычно 22)
- `GPAT` - GitHub Personal Access Token для доступа к репозиторию

### 3. Структура пользователей

- **Admin пользователь** (root/admin): Используется только для первоначальной настройки сервера
- **Deploy пользователь**: Используется для всех операций развертывания, имеет доступ к Docker без sudo прав

## Процесс развертывания

### Автоматическое развертывание

При push в ветку `main`:

1. **Проверка доступа**: Проверяется доступ пользователя deploy к Docker
2. **Клонирование/обновление**: Репозиторий клонируется или обновляется в `/opt/soultips/nginx/`
3. **Развертывание**: Приложение развертывается от имени deploy пользователя без sudo прав

### Ручное развертывание

```bash
# Локальное развертывание (требует sudo)
./deploy.sh

# Принудительное развертывание
./deploy.sh --force
```

## Настройка TLS

TLS сертификаты настраиваются вручную на сервере:

```bash
# Войти на сервер
ssh deploy@your-server

# Перейти в директорию проекта
cd /opt/soultips/nginx

# Настроить TLS сертификаты
./init-letsencrypt.sh
```

## Управление сервисами

```bash
# Просмотр статуса
docker-compose ps

# Просмотр логов
docker logs soultips_nginx

# Перезапуск
docker-compose restart

# Остановка
docker-compose down

# Обновление и перезапуск
docker-compose pull && docker-compose up -d
```

## Домены

Настройте следующие DNS записи:

- `soultipsdev.ru` → IP сервера
- `www.soultipsdev.ru` → IP сервера  
- `api.soultipsdev.ru` → IP сервера
- `www.api.soultipsdev.ru` → IP сервера

## Безопасность

- Пользователь deploy **НЕ имеет** sudo прав
- Доступ к Docker настроен через группу `docker`
- TLS сертификаты обновляются автоматически
- Nginx настроен с безопасными заголовками

## Структура файлов

```
/opt/soultips/nginx/
├── conf.d/
│   └── soultips.conf          # Конфигурация виртуальных хостов
├── tls/                       # TLS сертификаты
├── webroot/                   # Webroot для certbot
├── docker-compose.yml         # Docker Compose конфигурация
├── nginx.conf                 # Основная конфигурация nginx
├── deploy.sh                  # Скрипт развертывания
└── init-letsencrypt.sh        # Скрипт настройки TLS
```

## Troubleshooting

### Проблемы с правами доступа

```bash
# Проверить, что deploy пользователь в группе docker
groups deploy

# Проверить доступ к Docker
sudo -u deploy docker --version
```

### Проблемы с TLS

```bash
# Проверить статус certbot
docker-compose logs certbot

# Принудительное обновление сертификатов
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot --force-renewal
```

### Проблемы с развертыванием

```bash
# Проверить логи развертывания
docker-compose logs nginx

# Проверить конфигурацию nginx
docker-compose exec nginx nginx -t
``` 