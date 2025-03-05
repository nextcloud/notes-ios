#!/usr/bin/env bash

# Disable password policy app to enable simple testing passwords.
./occ app:disable password_policy

# Install the notes app.
./occ app:install notes

# Create some users.
export OC_PASS=password

./occ user:add --display-name="No Notes" --password-from-env nonotes
./occ user:setting nonotes core lang en
mkdir -p ./data/nonotes/files/Notes

./occ user:add --display-name="Many Notes" --password-from-env manynotes
./occ user:setting manynotes core lang en
mkdir -p ./data/manynotes/files/Notes