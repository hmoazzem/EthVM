#!/usr/bin/env bash

# Give script sane defaults
set -o errexit
# set -o nounset
# set -o xtrace
# set -o verbose

# Useful VARS
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR=$(cd ${SCRIPT_DIR}/..; pwd)

# import utils
source ${SCRIPT_DIR}/utils.sh

# verify we have required utilities installed
ensure

# docker_usage - prints docker subcommand usage
docker_usage() {
  echo ""
  echo "Utility that wraps docker / docker-compose commands to spin up a EthVM development environment."
  echo ""
  echo "Usage:"
  echo "  ethvm docker [COMMAND] [ARGS...]"
  echo ""
  echo "Commands:"
  echo "  up      [full|simple|default]   Create and start docker containers."
  echo "  start                           Start stopped docker containers."
  echo "  stop                            Stop docker containers."
  echo "  down                            Stop and remove docker containers, networks, images, and volumes."
  echo "  rebuild                         Build or rebuild docker services."
  echo "  restart                         Restart docker services."
  echo "  logs                            View output from containers."
  echo "  help                            Print the help information and exit."
  echo ""
}

# invalid - prints invalid message
invalid() {
  >&2 echo "Invalid argument passed!"
  >&2 echo ""
}

# up - process which option is going to be run to bring up the dev environment
up() {
  local type="${1:-"default"}"
  case "$type" in
    default) down; up_default ;;
    simple)  down; up_simple  ;;
    full)    down; up_full    ;;
    *)       invalid          ;;
  esac
}

# up - spins up a clean dev environment (but it will not run eth client, neither bolt in order to control the flow of data)
up_default() {
  echo -e "Starting up containers...\n"
  docker-compose up -d --build

  echo -e "Waiting 15 seconds to allow previous docker services initialisation..."
  sleep 15

  echo -e "Creating kafka topics...\n"
  ${SCRIPT_DIR}/kafka.sh create-topics

  echo "Initialisation of mongo...\n"
  ${SCRIPT_DIR}/mongo.sh init
}

# up_full - spins up a full automated environment where everything is going to run on docker
#           Keep in mind that this mode can hog your machine
up_full() {
  up

  echo "Starting up extra containers: ethereumj, bolt"
  ${DOCKER_COMPOSE} -f docker-compose.extra.yaml up -d --build
}

# up - spins up a dev environment with a fixed dataset ready to be used on frontend
up_simple() {
  echo "Starting up containers: traefik, mongo, redis, server and api"
  docker-compose up -d --build traefik mongodb redis server api

  echo -e "\nWaiting 10 seconds to allow previous docker containers initialisation...\n"
  sleep 10

  echo "Initialisation of mongo"
  ${SCRIPT_DIR}/mongo.sh init

  echo "Importing bootstraped db to mongo..."
  ${SCRIPT_DIR}/mongo.sh bootstrap
}

# down - stops all running docker containers, volumes, images and related stuff
start() {
  docker-compose start
}

# down - stops all running docker containers, volumes, images and related stuff
stop() {
  docker-compose stop
}

# down - stops all running docker containers, volumes, images and related stuff
down() {
  docker-compose down -v --remove-orphans
}

# restart - restart docker services
restart() {
  docker-compose restart
}

# logs - outputs logs for containers
logs() {
  docker-compose logs "$1"
}

run() {
  local command="${1}"
  local action="${2}"

  case "${command}" in
    up)      up "${action}"       ;;
    start)   start                ;;
    stop)    stop                 ;;
    down)    down                 ;;
    restart) restart              ;;
    logs)    logs "$2"            ;;
    help|*)  docker_usage; exit 0 ;;
  esac
}
run "$@"
