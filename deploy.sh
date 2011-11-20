#!/bin/sh
set -e

git remote update && git reset --hard $1
npm install --mongodb:native

./node_modules/.bin/coffee -c index.coffee app.coffee
./node_modules/.bin/stylus -c public/style.styl
