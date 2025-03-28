#! /usr/bin/env bash

. scripts/lib.sh

declare-repo github-public-repo "
  api=github/public
  url=github.com
  user=Vanille-N
  project=hello-world-public
  sha=f9c22e5f181864e8c26a69477185879ee64b6488
"

# Make sure that the access token you give only provides "api_read" access.
# A "Maintainer" role is needed, though.
# Tip: if you do not wish to expose this token, you can use
#   token=${TOKEN}
# and put the token in an environment variable instead of it being hardcoded.
# In fact, you can do the same for the sha.
declare-repo gitlab-private-repo "
  api=gitlab/apiv4
  url=gitlab.com
  project=hello-world-private
  pid=68468614
  token=glpat-tbszUGLZ5tPSykUz1vmU
  sha=d6082d5524240387ab9acbb33eb4ff23427ab379
"

prepare-download
unpack gitlab-private-repo gitlab-private
unpack github-public-repo github-public
finish-download

prepare-archive
copy README.md
copy Dockerfile
compress gitlab-private@. gitlab-private-source
compress github-public@. github-public-source
build-docker helloworld
finish-archive

