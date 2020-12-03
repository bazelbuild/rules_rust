#!/bin/bash -eux

[[ "$("${1}" --name Gibson)" == "Greetings, Gibson" ]] || exit 1
