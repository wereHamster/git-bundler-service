#!/bin/sh

ROOT="$1/data/bundles/$2"

mkdir -p "$ROOT/repo"
cd "$ROOT/repo"

git init --bare
git remote add origin --mirror "$3"

git fetch origin; git remote prune origin
git bundle create "$ROOT/bundle" --all

