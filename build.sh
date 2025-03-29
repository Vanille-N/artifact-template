#! /usr/bin/env bash

. scripts/lib.sh

load-secret SHA_GH_HELLO_WORLD_PUBLIC
declare-repo github-public-repo "
  api=github/public
  url=github.com
  user=Vanille-N
  project=hello-world-public
  sha=${SHA_GH_HELLO_WORLD_PUBLIC}
"

# Make sure that the access token you give only provides "api_read" access.
# A "Maintainer" role is needed, though.
load-secret TOK_GL_HELLO_WORLD
load-secret SHA_GL_HELLO_WORLD_PRIVATE
declare-repo gitlab-private-repo "
  api=gitlab/apiv4
  url=gitlab.com
  project=hello-world-private
  pid=68468614
  token=${TOK_GL_HELLO_WORLD}
  sha=${SHA_GL_HELLO_WORLD_PRIVATE}
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

