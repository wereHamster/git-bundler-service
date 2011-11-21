#!/bin/sh
set -e

git fetch origin && git reset --hard $1
npm install --mongodb:native

./node_modules/.bin/coffee -c index.coffee app.coffee </dev/null
./node_modules/.bin/stylus -c public/style.styl </dev/null
