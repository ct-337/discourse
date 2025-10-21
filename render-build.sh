#!/bin/bash
set -e
set -x

# Force reinstall of Bundler to fix corrupted gem path
gem uninstall bundler -aIx || true
gem install bundler -v 2.4.22

# Confirm Ruby and Bundler
ruby -v
bundle -v

# Install Ruby gems
bundle install --jobs=4 --retry=3

# Install Node dependencies
yarn install --check-files

# Migrate DB and compile assets
bundle exec rake db:migrate
bundle exec rake assets:precompile
