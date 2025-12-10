# Copytrade Nginx Configuration

Конфигурация Nginx для проекта Copytrade с автоматическим CI/CD развертыванием.

## 🚀 Быстрый старт

```bash
# На сервере
cd /opt/polycopy/nginx
docker compose up -d
./init-letsencrypt-copytrade.sh
```

## 🌐 Домены

### Backend API
- `api.copytrade.gg`
- `www.api.copytrade.gg` (редирект на основной)

### Frontend
- `onlyfirstonlyhigh.copytrade.gg`
- `www.onlyfirstonlyhigh.copytrade.gg`

## ⚙️ Конфигурация

### Proxy настройки
Nginx проксирует запросы по IP:
- Backend: `http://91.99.224.254:8001`
- Frontend: `http://91.99.224.254:3000`

**Примечание**: Docker сеть не используется - связь через прямые IP адреса.

## 📋 Требования

- Docker & Docker Compose
- Открытые порты: 80, 443
- Настроенные DNS записи для всех доменов

## 🔧 Основные команды

```bash
# Запуск
docker compose up -d

# Остановка
docker compose down

# Перезагрузка конфигурации
docker compose exec nginx nginx -s reload

# Проверка конфигурации
docker compose exec nginx nginx -t

# Просмотр логов
docker compose logs -f nginx
```

## 🔒 SSL/TLS

SSL сертификаты получаются автоматически через Let's Encrypt:

```bash
./init-letsencrypt-copytrade.sh
```

Автоматическое обновление каждые 12 часов через certbot контейнер.

## 🤖 CI/CD

GitHub Actions автоматически деплоит изменения при push в main.

### Требуемые secrets:
- `HOST` - IP сервера
- `USERNAME` - SSH пользователь
- `PASSWORD` - SSH пароль
- `PORT` - SSH порт
- `GPAT` - GitHub Personal Access Token

### Репозиторий:
https://github.com/TaroHarado/copytrade-nginx

## 📁 Структура

```
/opt/polycopy/nginx/
├── conf.d/
│   └── copytrade.conf          # Конфигурация для доменов
├── nginx.conf                   # Основная конфигурация
├── docker-compose.yml           # Docker Compose
├── init-letsencrypt-copytrade.sh # Получение SSL
├── deploy-copytrade.sh          # Скрипт развертывания
└── .github/workflows/
    └── copytrade.yml            # CI/CD
```

## 🔍 Troubleshooting

### 502 Bad Gateway
Проверьте доступность backend/frontend:
```bash
curl http://91.99.224.254:8001
curl http://91.99.224.254:3000
```

### SSL не получается
Проверьте DNS:
```bash
nslookup api.copytrade.gg
nslookup onlyfirstonlyhigh.copytrade.gg
```

### Nginx не запускается
Проверьте конфигурацию:
```bash
docker compose exec nginx nginx -t
docker compose logs nginx
```

## 📝 Deployment

При первом развертывании:
1. Настроить DNS записи
2. Запустить: `docker compose up -d`
3. Получить SSL: `./init-letsencrypt-copytrade.sh`

При обновлениях:
- Изменения автоматически деплоятся через GitHub Actions
- Или вручную: `git pull && docker compose restart nginx`

## 🛡️ Безопасность

- ✅ TLS 1.2 и 1.3
- ✅ Современные cipher suites
- ✅ HTTP → HTTPS редиректы
- ✅ Автоматическое обновление SSL

---

**Репозиторий**: https://github.com/TaroHarado/copytrade-nginx  
**Путь на сервере**: `/opt/polycopy/nginx`
