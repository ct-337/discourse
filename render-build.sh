#!/bin/bash

# Fail fast and show commands
set -e
set -x

# Confirm Ruby and Bundler
ruby -v
bundle -v

# Install Ruby gems
bundle install --jobs=4 --retry=3

# Install Node.js dependencies
yarn install --check-files

# Run database migrations
bundle exec rake db:migrate

# Precompile frontend assets
bundle exec rake assets:precompile
