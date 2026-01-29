#!/bin/bash

printf "I will be waiting until I receive SIGTERM using Ctrl+C or the other signals SIGINT, SIGABRT or SIGHUP\n"

function graceful_exit() {
  exit 0
}

trap graceful_exit SIGTERM SIGINT SIGABRT SIGHUP

tail -f /dev/null &
wait