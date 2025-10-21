#!/bin/bash

# Ensure bundler is installed
gem install bundler

# Install Ruby gems
bundle config set deployment 'true'
bundle config set without 'development test'
bundle install --jobs=4 --retry=3

# Precompile assets (Discourse needs this)
bundle exec rake assets:precompile

# Exit cleanly
exit 0
