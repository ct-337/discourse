#!/bin/bash

# Fail fast on errors
set -e

# Print commands for debugging
set -x

# Ensure Ruby and Bundler are available
ruby -v
bundle -v

# Install gem dependencies
bundle install --jobs=4 --retry=3

# Only run setup if we're in production
if [ "$RAILS_ENV" = "production" ]; then
  # Migrate the database
  bundle exec rake db:migrate

  # Precompile assets
  bundle exec rake assets:precompile
fi
