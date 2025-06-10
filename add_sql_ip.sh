#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
# IMPORTANT: Replace with your actual project ID and Cloud SQL instance name
export GOOGLE_CLOUD_PROJECT="docker-id-123" # e.g., my-flask-app-project-12345
CLOUD_SQL_INSTANCE_NAME="my-flask-db"

# --- IP Address to Authorize ---
# This can be your current public IP, or a specific IP range (e.g., "203.0.113.45/32")
# To get your current Cloud Shell external IP:
#NEW_IP_TO_AUTHORIZE=$(curl -s ipinfo.io/ip)
NEW_IP_TO_AUTHORIZE=$(curl -s ipinfo.io/ip)/32
# To use a fixed IP:
#NEW_IP_TO_AUTHORIZE="[YOUR_NEW_IP_ADDRESS_OR_RANGE]" # e.g., "203.0.113.45/32" or "192.0.2.0/24"

# --- Colors for output ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Safely Adding IP to Cloud SQL Authorized Networks ---${NC}"
echo -e "${YELLOW}Target Project: ${GOOGLE_CLOUD_PROJECT}${NC}"
echo -e "${YELLOW}Target Instance: ${CLOUD_SQL_INSTANCE_NAME}${NC}"
echo -e "${YELLOW}IP Address/Range to Add: ${NEW_IP_TO_AUTHORIZE}${NC}"

# --- Pre-requisite Check: jq ---
if ! command -v jq &> /dev/null
then
    echo -e "${RED}Error: 'jq' is not installed. Please install it (e.g., sudo apt install jq) and try again.${NC}"
    exit 1
fi

# --- 1. Get the current authorized networks ---
echo -e "${YELLOW}Retrieving current authorized networks...${NC}"
# Use jq to parse the JSON output and extract the 'value' of each authorized network.
# Then, use tr to convert newline-separated IPs to a comma-separated string.
# sed is used to remove any trailing comma.
CURRENT_NETWORKS=$(gcloud sql instances describe "$CLOUD_SQL_INSTANCE_NAME" \
    --project="$GOOGLE_CLOUD_PROJECT" \
    --format="json" \
    | jq -r '.settings.ipConfiguration.authorizedNetworks[].value' \
    | tr '\n' ',' \
    | sed 's/,$//') # Remove trailing comma

echo -e "${BLUE}Currently authorized networks:${NC}"
if [[ -z "$CURRENT_NETWORKS" ]]; then
    echo -e "${YELLOW}  (None)${NC}"
else
    echo -e "${BLUE}  ${CURRENT_NETWORKS}${NC}"
fi

# --- 2. Combine current and new IP, ensuring uniqueness ---
echo -e "${YELLOW}Combining current and new IP, ensuring uniqueness...${NC}"

# If there are no current networks, the new IP becomes the only one.
if [[ -z "$CURRENT_NETWORKS" ]]; then
    COMBINED_NETWORKS="${NEW_IP_TO_AUTHORIZE}"
else
    # Combine, convert to newlines, sort unique, then convert back to commas.
    COMBINED_NETWORKS=$(echo "${CURRENT_NETWORKS},${NEW_IP_TO_AUTHORIZE}" \
        | tr ',' '\n' \
        | sort -u \
        | tr '\n' ',' \
        | sed 's/,$//') # Remove trailing comma
fi

echo -e "${BLUE}Proposed updated authorized networks: ${COMBINED_NETWORKS}${NC}"

# --- 3. Patch the Cloud SQL instance with the combined list ---
echo -e "${YELLOW}Patching Cloud SQL instance with the updated list...${NC}"
gcloud sql instances patch "$CLOUD_SQL_INSTANCE_NAME" \
    --authorized-networks="$COMBINED_NETWORKS" \
    --project="$GOOGLE_CLOUD_PROJECT"

echo -e "${GREEN}Successfully updated authorized networks for ${CLOUD_SQL_INSTANCE_NAME}!${NC}"
echo -e "${YELLOW}It may take a few moments for the changes to take effect.${NC}"
echo -e "${YELLOW}You can verify by running: gcloud sql instances describe ${CLOUD_SQL_INSTANCE_NAME} --project=${GOOGLE_CLOUD_PROJECT} --format='value(settings.ipConfiguration.authorizedNetworks)'${NC}"

