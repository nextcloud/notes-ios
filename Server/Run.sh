#!/usr/bin/env zsh

SCRIPT_DIR=$(dirname "$0")
CONTAINER_NAME="nextcloud-notes-server"
NEXTCLOUD_TRUSTED_DOMAINS="${NEXTCLOUD_TRUSTED_DOMAINS:-localhost}"

docker run \
    --name $CONTAINER_NAME \
    --detach \
    --publish 8080:80 \
    --env SQLITE_DATABASE=nextcloud.sqlite \
    --env NEXTCLOUD_ADMIN_USER=admin \
    --env NEXTCLOUD_ADMIN_PASSWORD=admin \
    --env NEXTCLOUD_TRUSTED_DOMAINS="$NEXTCLOUD_TRUSTED_DOMAINS" \
    nextcloud

docker cp "$SCRIPT_DIR/Provisioning.sh" "$CONTAINER_NAME":/var/www/html/Provisioning.sh
echo "Waiting 10 seconds for the container to be ready before executing provisioning script..."
sleep 5
docker exec --user=www-data "$CONTAINER_NAME" ./Provisioning.sh
docker cp "$SCRIPT_DIR/Notes" "$CONTAINER_NAME":/var/www/html/data/manynotes/files/