#!/bin/sh

export RACK_ENV=development

bundle exec falcon serve -b http://localhost -p 4567 -n 1 --threaded
