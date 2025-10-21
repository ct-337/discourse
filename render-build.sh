#!/bin/bash
set -e
set -x

# Install Bundler
gem install bundler -v 2.4.22

# Reinstall nokogiri from source
gem install nokogiri -v 1.15.4 -- --use-system-libraries

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
