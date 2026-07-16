#!/usr/bin/env bash
# Activate Ruby 4 with isolated gem directory in /tmp
export GEM_HOME="/tmp/gems-ruby4"
export GEM_PATH="$GEM_HOME"
export BUNDLE_PATH="$GEM_HOME"
export PATH="$GEM_HOME/bin:$PATH"
mise use ruby@4
eval "$(mise activate bash)"
echo "Ruby: $(ruby --version)"
echo "Gems: $GEM_HOME"
