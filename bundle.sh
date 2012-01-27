#!/bin/sh
set -e

ROOT="$1/data/bundles/$2"

GIT_DIR="$ROOT/repo"; export GIT_DIR
mkdir -p "$GIT_DIR"

git init --bare
git remote add origin -f --mirror "$3"
git bundle create "$ROOT/bundle" --all

rm -rf $GIT_DIR
