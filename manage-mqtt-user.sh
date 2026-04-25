#!/bin/bash

# --- CONFIG ---
SERVICE_NAME="mosquitto"                # service name in docker-compose.yml
COMPOSE_FILE="compose.yml"
PASSWD_FILE_HOST="./config/passwd_file" # host path (mounted volume)
PASSWD_FILE_CONTAINER="/mosquitto/config/passwd_file"

# --- INPUT CHECK ---
if [ "$#" -lt 2 ]; then
  echo "Usage:"
  echo "  $0 add <username> [password]"
  echo "  $0 delete <username>"
  exit 1
fi

ACTION=$1
USERNAME=$2
PASSWORD=$3

# --- CHECK COMPOSE FILE ---
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ compose.yml not found."
  exit 1
fi

# --- CHECK IF CONTAINER IS RUNNING ---
echo "🔍 Checking container state..."

RUNNING=$(docker compose -f "$COMPOSE_FILE" ps --status running -q "$SERVICE_NAME")

if [ -n "$RUNNING" ]; then
  echo "✅ Container already running (ID: $RUNNING)"
  CONTAINER_ID="$RUNNING"
else
  echo "⚠️ Container not running. Ensuring image + starting..."

  # Pull image only if needed (safe to call regardless, but we skip when already running)
  docker compose -f "$COMPOSE_FILE" pull "$SERVICE_NAME"
  if [ $? -ne 0 ]; then
    echo "❌ Failed to pull image."
    exit 1
  fi

  # Start/create container
  docker compose -f "$COMPOSE_FILE" up -d "$SERVICE_NAME"
  if [ $? -ne 0 ]; then
    echo "❌ Failed to start container."
    exit 1
  fi

  # Get container ID
  CONTAINER_ID=$(docker compose -f "$COMPOSE_FILE" ps -q "$SERVICE_NAME")

  if [ -z "$CONTAINER_ID" ]; then
    echo "❌ Could not determine container ID."
    exit 1
  fi

  echo "✅ Container started (ID: $CONTAINER_ID)"
fi

# --- ENSURE PASSWORD FILE EXISTS ---
if [ ! -f "$PASSWD_FILE_HOST" ]; then
  echo "⚠️ Password file missing. Creating..."

  # Create empty file on host
  mkdir -p "$(dirname "$PASSWD_FILE_HOST")"
  touch "$PASSWD_FILE_HOST"

  # Initialize with a dummy user, then delete (mosquitto requires proper format)
  docker exec "$CONTAINER_ID" \
    mosquitto_passwd -b "$PASSWD_FILE_CONTAINER" tempuser temppass

  docker exec "$CONTAINER_ID" \
    mosquitto_passwd -D "$PASSWD_FILE_CONTAINER" tempuser

  echo "✅ Password file initialized."
fi

# --- PERFORM ACTION ---
case "$ACTION" in
  add)
    if [ -z "$PASSWORD" ]; then
      echo "🔐 Adding user '$USERNAME' (interactive)..."
      docker exec -it "$CONTAINER_ID" \
        mosquitto_passwd "$PASSWD_FILE_CONTAINER" "$USERNAME"
    else
      echo "🔐 Adding/updating user '$USERNAME'..."
      docker exec "$CONTAINER_ID" \
        mosquitto_passwd -b "$PASSWD_FILE_CONTAINER" "$USERNAME" "$PASSWORD"
    fi

    if [ $? -eq 0 ]; then
      echo "✅ User '$USERNAME' added/updated."
    else
      echo "❌ Failed to add/update user."
      exit 1
    fi
    ;;

  delete)
    echo "🗑️ Deleting user '$USERNAME'..."
    docker exec "$CONTAINER_ID" \
      mosquitto_passwd -D "$PASSWD_FILE_CONTAINER" "$USERNAME"

    if [ $? -eq 0 ]; then
      echo "✅ User '$USERNAME' deleted."
    else
      echo "❌ Failed to delete user."
      exit 1
    fi
    ;;

  *)
    echo "❌ Invalid action: $ACTION"
    exit 1
    ;;
esac

# --- OPTIONAL: RELOAD MOSQUITTO ---
echo "🔄 Reloading Mosquitto configuration..."
docker exec "$CONTAINER_ID" kill -HUP 1

echo "🎉 Operation completed successfully."