#!/bin/bash

# Install bundler and OpenSSL support
gem install bundler
gem install openssl

# Optional: install railties if needed
gem install railties -v '6.1.7.2'

# Bundle install with production-only gems
bundle config set deployment 'true'
bundle config set without 'development test'
bundle install --jobs=4 --retry=3

# Skip asset precompile for now
# bundle exec rake assets:precompile

exit 0
