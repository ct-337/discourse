#!/bin/bash

# Ensure bundler is installed
gem install bundler

# Install Ruby gems
bundle install --jobs=4 --retry=3

# Precompile assets (optional but recommended)
bundle exec rake assets:precompile

# Exit cleanly
exit 0
