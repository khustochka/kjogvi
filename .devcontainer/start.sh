#!/bin/bash

mix deps.get
mix ecto.setup
MIX_ENV=test mix ecto.setup

# Need to run 
# > eval "$(direnv hook bash)"
