#!/bin/bash

# Proper error handling
set -eu

# Re-apply exported host Git configuration
# https://github.com/microsoft/vscode-remote-release/issues/2084
conf=.gitconfig.global
if [ -f "$conf" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
    commit.gpgsign | url.* | user.*)
      echo "Setting Git config ${key}=${value}"
      git config --global "$key" "$value"
      ;;
    esac
  done < "$conf"
  rm -f "$conf"
fi

# Set working directory as safe to avoid Git "dubious ownership" error
echo "Adding \"$(pwd)\" as Git safe directory"
git config --global --add safe.directory "$(pwd)"
