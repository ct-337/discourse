#!/bin/bash

# Update system packages
apt-get update

# Install native build tools required by mini_racer and libv8
apt-get install -y build-essential libv8-dev python3

# Install Node.js headers (needed for mini_racer)
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Ruby dependencies
bundle install

# Exit cleanly
exit 0
