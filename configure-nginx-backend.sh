#!/bin/bash

# Initialize Managed Data Disk
DISK_NAME=$(lsblk -I 8 -d -o NAME,SIZE | grep 4G | grep -Po 'sd\S*')
sudo parted /dev/${DISK_NAME} --script mklabel gpt mkpart xfspart xfs 0% 100%
PARTITION_LOCATION=/dev/${DISK_NAME}1
sudo mkfs.xfs ${PARTITION_LOCATION}
sudo partprobe ${PARTITION_LOCATION}
sudo mkdir -p /datadrive
sudo mount ${PARTITION_LOCATION} /datadrive
SD_UUID=$(blkid | grep -Po "$PARTITION_LOCATION: UUID=\"\K.*?(?=\")")
echo "${SD_UUID}   /datadrive   xfs   defaults,nofail   1   2" | sudo tee -a /etc/fstab

# Firewall config - using ufw (Uncomplicated Firewall)
sudo apt-get update
sudo apt-get install -y ufw
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp

# SSH server should already be installed and running on most Linux distros
# But we ensure it's installed and enabled
sudo apt-get install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# Install Nginx from package manager
sudo apt-get install -y nginx

# Create additional folders
sudo mkdir -p /datadrive/nginx/ssl
sudo mkdir -p /datadrive/nginx/data
sudo mkdir -p /datadrive/nginx/logs

# Copy Ssl certs from KeyVault
export SYMLINK_CERTNAME=$(sudo ls /var/lib/waagent/Microsoft.Azure.KeyVault.Store/ | grep -i -E ".workload-public-private-cert" | head -1)
sudo openssl x509 -in /var/lib/waagent/Microsoft.Azure.KeyVault.Store/${SYMLINK_CERTNAME} -out /datadrive/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.crt
sudo openssl rsa -in /var/lib/waagent/Microsoft.Azure.KeyVault.Store/${SYMLINK_CERTNAME} -out /datadrive/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.key

# Create home page
sudo wget -O /var/www/html/index.html https://raw.githubusercontent.com/mspnp/iaas-baseline/main/workload/index.html

# Configure Nginx with root page, ssl, health probe endpoint, and reverse proxy
cat <<'EOF' | sudo tee /etc/nginx/sites-available/backend
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    gzip  off;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /var/www/html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /var/www/html;
        }
    }

    server {
        listen 443 ssl;
        server_name backend.iaas-ingress.contoso.com;
        ssl_certificate /datadrive/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.crt;
        ssl_certificate_key /datadrive/nginx/ssl/nginx-ingress-internal-iaas-ingress-tls.key;
        ssl_protocols TLSv1.2 TLSv1.3;

        root /var/www/html;

        location / {
            access_log /datadrive/nginx/logs/backend.log combined buffer=10k flush=1m;
            index index.html;
            sub_filter '[backend]' '$hostname';
            sub_filter_once off;
        }

        location = /favicon.ico {
            empty_gif;
            access_log off;
        }
    }
}
EOF

# Create symbolic link to enable the site
sudo ln -sf /etc/nginx/sites-available/backend /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Initialize processed request count data file
echo "0" | sudo tee /datadrive/nginx/data/backend.data

# Create log rotation and processing script
cat <<'EOF' | sudo tee /datadrive/nginx/rotate-process-nginx-backend-logs.sh
#!/bin/bash

# Renaming
sudo mv /datadrive/nginx/logs/backend.log /datadrive/nginx/logs/backend.log.rot

# Send USR1 to reopen logs
sudo nginx -s reopen

# Get rotated log content
LAST_PROCESSED_REQUEST_CONTENT=$(cat /datadrive/nginx/logs/backend.log.rot)

# Process rotated log
LAST_PROCESSED_REQUEST_COUNT=$(wc -l < /datadrive/nginx/logs/backend.log.rot)

# Get current number of processed requests
CURRENT_PROCESSED_REQUEST_COUNT=$(cat /datadrive/nginx/data/backend.data)

# Write total number of processed requests
TOTAL_PROCESSED_REQUEST_COUNT=$((LAST_PROCESSED_REQUEST_COUNT + CURRENT_PROCESSED_REQUEST_COUNT))
echo $TOTAL_PROCESSED_REQUEST_COUNT | sudo tee /datadrive/nginx/data/backend.data

# Get last write time
LAST_WRITE_TIME=$(date -u +"%Y-%m-%d %H:%M:%SZ")

# Update workload content with total processed requests
sed -i "s|<h2>.*</h2>|<h2>Welcome to the Contoso WebApp! Your request has been load balanced through [frontend] and [backend] {{Total Processed Requests: $TOTAL_PROCESSED_REQUEST_COUNT, Last Update Time: $LAST_WRITE_TIME}}.</h2>|" /var/www/html/index.html

# Append recent rotated log content to a daily rotated log file
cat /datadrive/nginx/logs/backend.log.rot >> /datadrive/nginx/data/backend$(date +%Y-%m-%d).log
EOF

# Make script executable
sudo chmod +x /datadrive/nginx/rotate-process-nginx-backend-logs.sh

# Set up cron job for log rotation
(
    crontab -l 2>/dev/null
    echo "*/2 * * * * /datadrive/nginx/rotate-process-nginx-backend-logs.sh"
) | crontab -

# Restart Nginx to apply changes
sudo systemctl restart nginx
sudo systemctl enable nginx
