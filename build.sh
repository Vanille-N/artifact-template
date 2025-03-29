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

load-secret SHA_GL_HELLO_WORLD_PUBLIC
declare-repo gitlab-public-repo "
  api=gitlab/public
  url=gitlab.com
  user=Vanille-N
  project=hello-world-public
  sha=${SHA_GL_HELLO_WORLD_PUBLIC}
"

prepare-download
unpack gitlab-private-repo gitlab-private
unpack github-public-repo github-public
unpack gitlab-public-repo gitlab-public
finish-download

prepare-archive
copy README.md
copy Dockerfile
compress gitlab-private@. gitlab-private-source
compress github-public@. github-public-source
build-docker helloworld
finish-archive

