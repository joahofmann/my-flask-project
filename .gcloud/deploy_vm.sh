#!/bin/bash

# --- IMPORTANT: REPLACE PLACEHOLDERS BELOW ---
# --- IMPORTANT: REPLACE PLACEHOLDERS BELOW ---
# Replace with your actual Google Cloud Project ID
export GOOGLE_CLOUD_PROJECT="docker-id-123" # Suggestion: A unique, lowercase ID, often including a number or date. You can find this in the GCP Console.
# Choose a zone for your VM (e.g., us-central1-a, us-central1-c)
export GOOGLE_CLOUD_ZONE="us-central1-b" # Suggestion: A specific zone in the US. Common alternatives: "us-central1-a", "us-central1-c". Choose one geographically close to you or your users.
# Choose a region for your Cloud SQL instance (e.g., us-central1, asia-southeast1)
export GOOGLE_CLOUD_REGION="us-central1" # Suggestion: The broader region for your Cloud SQL instance. This should ideally be the region that contains your chosen zone. Common alternatives: "us-central1", "asia-southeast1".
# Choose strong passwords for your databases
export DB_ROOT_PASSWORD="MySuperStrongRootPass!2024" # Suggestion: MUST be a strong, unique password. Include uppercase, lowercase, numbers, and symbols. NEVER use this example password in production.
export FLASK_DB_PASSWORD="FlaskAppSecurePass#Abc" # Suggestion: MUST be a strong, unique password for your application's database user. Different from the root password. NEVER use this example password in production.
# --- END IMPORTANT ---

gcloud config set project $GOOGLE_CLOUD_PROJECT
gcloud config set compute/zone $GOOGLE_CLOUD_ZONE
gcloud config set sql/region $GOOGLE_CLOUD_REGION

echo "Configured project: $GOOGLE_CLOUD_PROJECT, zone: $GOOGLE_CLOUD_ZONE, region: $GOOGLE_CLOUD_REGION"

echo "Creating Compute Engine VM instance..."
gcloud compute instances create my-flask-vm \
    --project=$GOOGLE_CLOUD_PROJECT \
    --zone=$GOOGLE_CLOUD_ZONE \
    --machine-type=e2-micro \
    --image-family=debian-11 \
    --image-project=debian-cloud \
    --tags=http-server,https-server \
    --boot-disk-size=20GB \
    --metadata=startup-script="#! /bin/bash
    echo 'VM initial setup script running...'
    sudo apt update
    sudo apt install -y python3 python3-pip nginx postgresql-client
    echo 'Initial packages installed.'
    "
echo "VM 'my-flask-vm' creation initiated. External IP will be available shortly."

echo "Creating Cloud SQL for PostgreSQL instance..."
gcloud sql instances create my-flask-db \
    --database-version=POSTGRES_14 \
    --region=$GOOGLE_CLOUD_REGION \
    --cpu=1 \
    --memory=3840MiB \
    --storage-size=20GB \
    --project=$GOOGLE_CLOUD_PROJECT \
    --root-password=$DB_ROOT_PASSWORD
echo "Cloud SQL instance 'my-flask-db' creation initiated."

echo "Creating database user and database..."
gcloud sql users create flask_user \
    --instance=my-flask-db \
    --password=$FLASK_DB_PASSWORD \
    --host=% \
    --project=$GOOGLE_CLOUD_PROJECT

gcloud sql databases create my_flask_db \
    --instance=my-flask-db \
    --project=$GOOGLE_CLOUD_PROJECT
echo "Database user 'flask_user' and database 'my_flask_db' creation initiated."

echo "Waiting for Cloud SQL instance to be ready for IP authorization..."
gcloud sql instances describe my-flask-db --project=$GOOGLE_CLOUD_PROJECT --format="value(state)" | grep -q "RUNNABLE" || sleep 30

echo "Fetching VM external IP to authorize Cloud SQL connection..."
VM_EXTERNAL_IP=$(gcloud compute instances list --filter="name=(my-flask-vm)" --format="get(networkInterfaces[0].accessConfigs[0].natIP)")
echo "VM External IP: $VM_EXTERNAL_IP"

# Authorize your VM's external IP to connect to the Cloud SQL instance
gcloud sql instances patch my-flask-db \
    --authorized-networks=$VM_EXTERNAL_IP/32 \
    --project=$GOOGLE_CLOUD_PROJECT
echo "Cloud SQL instance authorized for connections from your VM."

echo "Fetching Cloud SQL instance details (Public IP)..."
CLOUD_SQL_PUBLIC_IP=$(gcloud sql instances describe my-flask-db --project=$GOOGLE_CLOUD_PROJECT --format="value(ipAddresses[0].ipAddress)")
echo "Cloud SQL Public IP (for app config): $CLOUD_SQL_PUBLIC_IP"
echo ""
echo "--- NEXT STEP: ---"
echo "1. Wait for VM and Cloud SQL to be fully provisioned (may take several minutes)."
echo "2. SSH into your VM:"
echo "   gcloud compute ssh my-flask-vm --zone=$GOOGLE_CLOUD_ZONE"
echo "3. Once on the VM, run the 'setup_nginx_gunicorn.sh' script located in your local .gcloud folder."
echo "   You will need to manually copy it or its contents to the VM. A simple way:"
echo "   gcloud compute scp .gcloud/setup_nginx_gunicorn.sh my-flask-vm:~ --zone=$GOOGLE_CLOUD_ZONE"
echo "   Then, on the VM: bash setup_nginx_gunicorn.sh"
