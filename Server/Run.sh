#!/usr/bin/env zsh

CONTAINER_NAME="nextcloud-notes-test-server"
NEXTCLOUD_TRUSTED_DOMAINS="${NEXTCLOUD_TRUSTED_DOMAINS:-localhost}"
NEXTCLOUD_URL="http://localhost:8080"
POLL_INTERVAL=1
SCRIPT_DIR=$(dirname "$0")

docker run \
    --name $CONTAINER_NAME \
    --detach \
    --publish 8080:80 \
    --env SQLITE_DATABASE=nextcloud.sqlite \
    --env NEXTCLOUD_ADMIN_USER=admin \
    --env NEXTCLOUD_ADMIN_PASSWORD=admin \
    --env NEXTCLOUD_TRUSTED_DOMAINS="$NEXTCLOUD_TRUSTED_DOMAINS" \
    nextcloud

echo "Waiting for Nextcloud to be set up..."

while true; do
  if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "Container '$CONTAINER_NAME' is not running. Waiting $POLL_INTERVAL seconds..."
    sleep "$POLL_INTERVAL"
    continue
  fi

  response=$(curl -s "$NEXTCLOUD_URL/status.php")

  if echo "$response" | grep -q '"installed":[[:space:]]*true'; then
    echo "Nextcloud is set up!"
    break
  else
    echo "Nextcloud is not set up yet. Waiting $POLL_INTERVAL seconds..."
    sleep "$POLL_INTERVAL"
  fi
done

echo "Provisioning..."
docker cp "$SCRIPT_DIR/Provisioning.sh" "$CONTAINER_NAME":/var/www/html/Provisioning.sh
docker exec --user=www-data "$CONTAINER_NAME" ./Provisioning.sh
docker cp "$SCRIPT_DIR/Notes" "$CONTAINER_NAME":/var/www/html/data/manynotes/files/
echo "Provisioning completed!"
