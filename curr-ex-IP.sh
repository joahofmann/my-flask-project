# Get your current external IP (if not already known)
MY_EXTERNAL_IP=$(curl -s ipinfo.io/ip)
echo "Your current external IP: $MY_EXTERNAL_IP"

# Authorize your IP in Cloud SQL (replace [YOUR_PROJECT_ID] and [YOUR_CLOUD_SQL_INSTANCE_NAME])
gcloud sql instances patch my-flask-db \
    --authorized-networks="${MY_EXTERNAL_IP}/32" \
    --project=docker-id-123
