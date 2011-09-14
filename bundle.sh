#!/bin/sh

ROOT="$1/data/bundles/$2"

GIT_DIR="$ROOT/repo"; export GIT_DIR
mkdir -p "$GIT_DIR"

git init --bare
git remote add origin --mirror "$3"

git fetch origin; git remote prune origin
git bundle create "$ROOT/bundle" --all

rm -rf $GIT_DIR
