#!/bin/bash

# Fail fast on any error
set -e

# Print each command before running (for easier debugging)
set -x

# Ensure correct Ruby version is used
ruby -v
bundle -v

# Install all gem dependencies
bundle install --jobs=4 --retry=3

# Run database migrations
bundle exec rake db:migrate

# Precompile frontend assets
bundle exec rake assets:precompile

# Optional: verify Redis connectivity (can be removed if not needed)
# bundle exec rake redis:check

# Optional: verify DB connectivity (can be removed if not needed)
# bundle exec rake db:check

# Done — Render will now run your Start Command
