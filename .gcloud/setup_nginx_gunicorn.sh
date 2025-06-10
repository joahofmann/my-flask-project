#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- IMPORTANT: REPLACE PLACEHOLDERS BELOW ---
# Get this from the output of the deploy_vm.sh script or `gcloud sql instances describe my-flask-db`
DB_HOST="34.9.236.250"
DB_NAME="my_flask_db"
DB_USER="flask_user"
DB_PASSWORD="FlaskAppSecurePass#Abc" # Must match the password used in deploy_vm.sh
# --- END IMPORTANT ---

# --- Colors for output ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Starting VM Application Setup ---${NC}"

# Ensure we are in the user's home directory initially
cd ~ || { echo -e "${RED}Error: Could not change to home directory. Exiting.${NC}"; exit 1; }

# --- 1. General System Updates and Software Installation (if not done by startup script) ---
echo -e "${YELLOW}Ensuring necessary packages are installed...${NC}"
sudo apt update
sudo apt install -y python3 python3-pip nginx postgresql-client
echo -e "${GREEN}Packages checked/installed.${NC}"

# --- 2. Create Application Directory and Files ---
echo -e "${YELLOW}Creating application directory and files...${NC}"
APP_DIR="/home/$(whoami)/my_flask_app"
mkdir -p "$APP_DIR"
cd "$APP_DIR" || { echo -e "${RED}Error: Could not change to application directory: $APP_DIR. Exiting.${NC}"; exit 1; }

# Create app.py
echo -e "${YELLOW}Creating app.py...${NC}"
cat << 'APP_EOF' > app.py
from flask import Flask
import os
import psycopg2
from psycopg2 import OperationalError

app = Flask(__name__)

@app.route('/')
def hello_world():
    return '<h1>Hello, World from Flask!</h1><p>Running with Gunicorn and Nginx on Google Cloud.</p>'

@app.route('/db_test')
def db_test():
    db_host = os.environ.get('DB_HOST')
    db_name = os.environ.get('DB_NAME')
    db_user = os.environ.get('DB_USER')
    db_password = os.environ.get('DB_PASSWORD')

    if not all([db_host, db_name, db_user, db_password]):
        return "<h1>Database Test Failed</h1><p>Database environment variables (DB_HOST, DB_NAME, DB_USER, DB_PASSWORD) are not set.</p>"

    conn = None
    try:
        conn = psycopg2.connect(
            host=db_host,
            database=db_name,
            user=db_user,
            password=db_password
        )
        cur = conn.cursor()
        cur.execute('SELECT version();')
        db_version = cur.fetchone()[0]
        cur.close()
        return f"<h1>Database Test Succeeded!</h1><p>Connected to PostgreSQL version: {db_version}</p>"
    except OperationalError as e:
        return f"<h1>Database Test Failed</h1><p>Could not connect to database: {e}</p>"
    except Exception as e:
        return f"<h1>An unexpected error occurred:</h1><p>{e}</p>"
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(debug=True, host='0.0.0.0', port=port)
APP_EOF

# Create requirements.txt
echo -e "${YELLOW}Creating requirements.txt...${NC}"
cat << 'REQ_EOF' > requirements.txt
Flask
gunicorn
psycopg2-binary
REQ_EOF

# Create gunicorn_config.py
echo -e "${YELLOW}Creating gunicorn_config.py...${NC}"
cat << 'GUNI_EOF' > gunicorn_config.py
workers = 4
bind = "0.0.0.0:8080"
timeout = 120
GUNI_EOF

# Create static directories and dummy files
echo -e "${YELLOW}Creating static files...${NC}"
mkdir -p static/{css,js,images}
cat << 'CSS_EOF' > static/css/style.css
/* static/css/style.css */
body {
    font-family: 'Inter', sans-serif;
    margin: 20px;
    background-color: #f0f2f5;
    color: #333;
}
h1 {
    color: #0056b3;
}
p {
    line-height: 1.6;
}
CSS_EOF

cat << 'JS_EOF' > static/js/script.js
// static/js/script.js
console.log("Hello from your Flask app's static JavaScript!");
document.addEventListener('DOMContentLoaded', () => {
    // Add any interactive JavaScript here
});
JS_EOF
touch static/images/logo.png # Dummy image file
echo -e "${GREEN}Static files created.${NC}"

# Create templates directories and dummy files
echo -e "${YELLOW}Creating template files...${NC}"
mkdir -p templates
cat << 'BASE_HTML_EOF' > templates/base.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}My Flask App{% endblock %}</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    <header>
        <nav>
            <a href="/">Home</a> | <a href="/db_test">DB Test</a>
        </nav>
    </header>
    <main>
        {% block content %}{% endblock %}
    </main>
    <footer>
        <p>&copy; 2024 My Flask App</p>
    </footer>
    <script src="{{ url_for('static', filename='js/script.js') }}"></script>
</body>
</html>
BASE_HTML_EOF

cat << 'INDEX_HTML_EOF' > templates/index.html
{% extends "base.html" %}
{% block title %}Home - My Flask App{% endblock %}
{% block content %}
    <h1>Welcome!</h1>
    <p>This is the home page of your Flask application.</p>
    <p>Check the database connection: <a href="/db_test">Test DB</a></p>
{% endblock %}
INDEX_HTML_EOF

cat << 'DB_TEST_HTML_EOF' > templates/db_test.html
{% extends "base.html" %}
{% block title %}DB Test - My Flask App{% endblock %}
{% block content %}
    <h1>Database Connection Test</h1>
    <p>This page will attempt to connect to the PostgreSQL database.</p>
    {# The actual DB test will happen in the /db_test route's Python code #}
DB_TEST_HTML_EOF
echo -e "${GREEN}Template files created.${NC}"

# Install Python dependencies
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip3 install -r requirements.txt
echo -e "${GREEN}Python dependencies installed.${NC}"

# --- 3. Configure Gunicorn Systemd Service ---
echo -e "${YELLOW}Configuring Gunicorn Systemd service...${NC}"
SERVICE_FILE="/etc/systemd/system/my_flask_app.service"

# Use sudo tee for reliable writing to privileged files
cat <<APP_SERVICE_EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Gunicorn instance to serve my_flask_app
After=network.target

[Service]
User=$(whoami)
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=/usr/bin:/bin:/usr/local/bin"
# Set database connection environment variables for the service
Environment="DB_HOST=$DB_HOST"
Environment="DB_NAME=$DB_NAME"
Environment="DB_USER=$DB_USER"
Environment="DB_PASSWORD=$DB_PASSWORD"
ExecStart=/usr/bin/python3 -m gunicorn --config $APP_DIR/gunicorn_config.py app:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
Restart=on-failure

[Install]
WantedBy=multi-user.target
APP_SERVICE_EOF

echo -e "${YELLOW}Reloading systemd, starting and enabling Gunicorn service...${NC}"
sudo systemctl daemon-reload || echo -e "${RED}Warning: systemctl daemon-reload failed. Check if systemd is running.${NC}"
sudo systemctl start my_flask_app || echo -e "${RED}Warning: systemctl start failed. Check if systemd is running and service file is correct.${NC}"
sudo systemctl enable my_flask_app || echo -e "${RED}Warning: systemctl enable failed. Check if systemd is running.${NC}"
echo -e "${YELLOW}Gunicorn service status:${NC}"
sudo systemctl status my_flask_app --no-pager || echo -e "${RED}Error: Could not get Gunicorn service status. Systemd issue suspected.${NC}"
echo -e "${GREEN}Gunicorn service configuration attempt complete.${NC}"

# --- 4. Configure Nginx as a Reverse Proxy ---
echo -e "${YELLOW}Configuring Nginx reverse proxy...${NC}"
NGINX_CONF_FILE="/etc/nginx/sites-available/my_flask_app"

sudo rm -f /etc/nginx/sites-enabled/default # Remove default Nginx config

# Use sudo tee for reliable writing to privileged files
cat <<NGINX_CONF_EOF | sudo tee "$NGINX_CONF_FILE" > /dev/null
server {
    listen 80;
    server_name _; # Listen on any hostname (can be changed to VM's external IP or domain)

    location / {
        proxy_pass http://127.0.0.1:8080; # Forward requests to Gunicorn
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
    }

    location /static/ {
        alias $APP_DIR/static/; # Serve static files directly by Nginx
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
NGINX_CONF_EOF

# Enable the Nginx site
echo -e "${YELLOW}Enabling Nginx site...${NC}"
sudo ln -sf "$NGINX_CONF_FILE" /etc/nginx/sites-enabled/my_flask_app

echo -e "${YELLOW}Testing Nginx configuration and restarting Nginx...${NC}"
sudo nginx -t && sudo systemctl restart nginx
echo -e "${YELLOW}Nginx service status:${NC}"
sudo systemctl status nginx --no-pager || echo -e "${RED}Error: Could not get Nginx service status. Systemd issue suspected.${NC}"
echo -e "${GREEN}Nginx configuration attempt complete.${NC}"

echo -e "${GREEN}--- VM Application Setup Complete! ---${NC}"
echo -e "${YELLOW}Please check the output above for any 'Error' or 'Warning' messages, especially related to systemd.${NC}"
echo -e "${YELLOW}Your Flask app should now be accessible via the VM's external IP if systemd and Nginx started successfully.${NC}"
echo -e "${YELLOW}Remember to open http://[YOUR_VM_EXTERNAL_IP] in your browser.${NC}"
echo -e "${YELLOW}Also test the database connection at http://[YOUR_VM_EXTERNAL_IP]/db_test.${NC}"
