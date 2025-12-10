#!/bin/bash

# Check for CI/CD environment
if [[ "$CI" == "true" ]] || [[ "$GITHUB_ACTIONS" == "true" ]]; then
    echo "Running in CI/CD mode - TLS certificates should be configured manually on the server"
    echo "This script is designed for manual TLS setup and should not run in automated deployment"
    exit 0
fi

if ! [ -x "$(command -v docker compose)" ]; then
  echo 'Error: docker compose is not installed.' >&2
  exit 1
fi

# Массивы доменов для разных сертификатов
backend_domains=(api.copytrade.gg www.api.copytrade.gg)
frontend_domains=(onlyfirstonlyhigh.copytrade.gg www.onlyfirstonlyhigh.copytrade.gg)

rsa_key_size=4096
data_path="./tls"
email="" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

# Функция для получения сертификата для группы доменов
get_certificate() {
    local domains=("$@")
    local primary_domain="${domains[0]}"
    
    echo "### Processing certificate for: ${domains[*]}"
    
    if [ -d "$data_path/live/$primary_domain" ]; then
        read -p "Existing data found for $primary_domain. Continue and replace existing certificate? (y/N) " decision
        if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
            echo "Skipping $primary_domain"
            return
        fi
    fi
    
    echo "### Creating dummy certificate for $primary_domain ..."
    path="/etc/letsencrypt/live/$primary_domain"
    mkdir -p "$data_path/conf/live/$primary_domain"
    docker compose run --rm --entrypoint "\
      openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
        -keyout '$path/privkey.pem' \
        -out '$path/fullchain.pem' \
        -subj '/CN=localhost'" certbot
    echo
    
    echo "### Deleting dummy certificate for $primary_domain ..."
    docker compose run --rm --entrypoint "\
      rm -Rf /etc/letsencrypt/live/$primary_domain && \
      rm -Rf /etc/letsencrypt/archive/$primary_domain && \
      rm -Rf /etc/letsencrypt/renewal/$primary_domain.conf" certbot
    echo
    
    echo "### Requesting Let's Encrypt certificate for $primary_domain ..."
    # Join domains to -d args
    domain_args=""
    for domain in "${domains[@]}"; do
      domain_args="$domain_args -d $domain"
    done
    
    # Select appropriate email arg
    case "$email" in
      "") email_arg="--register-unsafely-without-email" ;;
      *) email_arg="--email $email" ;;
    esac
    
    # Enable staging mode if needed
    if [ $staging != "0" ]; then staging_arg="--staging"; fi
    
    docker compose run --rm --entrypoint "\
      certbot certonly --webroot -w /var/www/certbot \
        $staging_arg \
        $email_arg \
        $domain_args \
        --rsa-key-size $rsa_key_size \
        --agree-tos \
        --force-renewal" certbot
    echo
}

# Скачиваем TLS параметры если их нет
if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

# Получаем сертификаты для всех доменов
get_certificate "${backend_domains[@]}"
get_certificate "${frontend_domains[@]}"

echo "### Starting nginx ..."
docker compose up --force-recreate -d nginx
echo

echo "### Reloading nginx ..."
docker compose exec nginx nginx -s reload

echo "### Done! All certificates have been obtained."


