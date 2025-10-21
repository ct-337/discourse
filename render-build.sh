#!/bin/bash

gem install bundler
gem install railties -v '6.1.7.2'

bundle config set deployment 'true'
bundle config set without 'development test'
bundle install --jobs=4 --retry=3

bundle exec rake assets:precompile
exit 0
