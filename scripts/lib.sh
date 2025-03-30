#! /usr/bin/env bash

assert-nosplit () {
  if [ -n "$2" ]; then
    echo "This word should not be splittable."
    echo "  '$@'"
    exit 33
  fi
}

wf () {
  local MSG="$1"
  shift
  if ! "$@" &> /dev/null; then
    echo "Assumption failed: $MSG"
    echo "  at ${FUNCNAME[1]}"
    exit 1
  fi
}

BUILD_PHASE=none

requires-context () {
  local CTX=$1
  if [ $BUILD_PHASE != $CTX ]; then
    echo "The function '${FUNCNAME[1]}' can only be executed in context '$CTX'."
    echo "Currently in context '$BUILD_PHASE'"
    echo "Use the appropriate 'prepare-*' or 'finish-*'"
    exit 33
  fi
}

switch-context () {
  BUILD_PHASE=$1
}

declare -A REPOS

record () {
  assert-nosplit $1; local DIR=$1
  assert-nosplit $2; local KEY=$2
  assert-nosplit $3; local VAL=$3
  REPOS[${DIR}:${KEY}]=${VAL}
}

query () {
  local NAME=$1
  local KEY=$2
  local PAIR="$1:$2"
  if ! [ ${REPOS[$PAIR]+exists} ]; then
    echo "Repository `$NAME` does not have the key `$KEY` which api ${REPOS[$NAME:api]} requires"
  fi
  ANS=${REPOS[$PAIR]}
}

declare-repo () {
  requires-context none
  assert-nosplit $1; local NAME=$1
  local CFG="$2"
  for ENTRY in $CFG; do
    IFS='='; KV=($ENTRY); unset IFS;
    record $NAME ${KV[0]} ${KV[1]}
  done
}

load-secret () {
  requires-context none
  assert-nosplit $1; local FILE=$1
  ANS=$( head -n1 "SECRETS/$FILE" )
  # TODO: validation if it doesn't exist
  eval "$FILE=$ANS"
}

DOWNLOAD_DIR=_download

prepare-download () {
  requires-context none
  mkdir -p $DOWNLOAD_DIR
  cd $DOWNLOAD_DIR
  switch-context download
}

finish-download () {
  requires-context download
  cd ..
  switch-context none
}

unpack () {
  requires-context download
  assert-nosplit $1; local NAME=$1
  assert-nosplit $2; local DEST=$2
  case ${REPOS[$NAME:api]} in
    ('') echo "Repository $NAME does not have an api declared."; exit 1;;
    (github/public) get-github-public-archive $NAME $DEST;;
    (gitlab/apiv4) get-gitlab-api-archive $NAME $DEST;;
    (gitlab/public) get-gitlab-public-archive $NAME $DEST;;
    (*) echo "${REPOS[$NAME:api]} is not one of the supported APIs"; exit 1;;
  esac
}

NTH_ARCHIVE=
ARCHIVE_DIR=

prepare-archive () {
  requires-context none
  case "$1" in
    (_final*) echo "Archive name '_final*' is reserved. Choose something else."; exit 1;;
    ($DOWNLOAD_DIR) echo "Archive name '$DOWNLOAD_DIR' is reserved. Choose something else."; exit 1;;
    (*/*) echo "Archive name should not contain '/'."; exit 1;;
    ('') ARCHIVE_DIR=_final$NTH_ARCHIVE
         let 'NTH_ARCHIVE++';;
    (*) assert-nosplit $1; ARCHIVE_DIR=$1
  esac
  mkdir -p $ARCHIVE_DIR
  cd $ARCHIVE_DIR
  : > md5sums
  switch-context archive
}

finish-archive () {
  requires-context archive
  cd ..
  case "$1" in
    ('+tar') tar czf $ARCHIVE_DIR.tar.gz $ARCHIVE_DIR
    (*) # TODO: fail gracefully
      exit 1;;
  esac
  switch-context none
}

copy () {
  requires-context archive
  local FILE="$1"
  cp "../$FILE" .
}

compress () {
  requires-context archive
  local LOCATION="$1"
  assert-nosplit $2; local DEST="$2"
  IFS='@'; SPLIT=($LOCATION); unset IFS;
  local DIR="../$DOWNLOAD_DIR/${SPLIT[1]}"
  local SRC="${SPLIT[0]}"

  tar czf "$DEST.tar.gz" --directory="$DIR" "$SRC"
  md5sum "$DEST.tar.gz" >> md5sums
}

build-docker () {
  requires-context archive
  assert-nosplit $1; local CONTAINER=$1
  docker build -t $CONTAINER .
  # TODO: Don't forget to docker save
}

get-github-public-archive () {
  local NAME=$1
  local DEST=$2
  query $NAME url; local SERVER=$ANS
  query $NAME user; local USER=$ANS
  query $NAME project; local PROJECT=$ANS
  query $NAME sha; local SHA=$ANS

  rm -rf "$DEST"
  echo "Required: $USER/$PROJECT"
  echo "  at $SHA"
  echo "  from $SERVER"
  if [ -f "$SHA.tar.gz" ]; then
    echo "Already downloaded"
  else
    URL="https://$SERVER/$USER/$PROJECT/archive/$SHA.tar.gz"
    echo "Fetching from $URL"
    wget -q "$URL"
  fi
  echo "Unpacking to folder: $DEST/"
  tar xf "$SHA.tar.gz"
  mv "$PROJECT-$SHA" "$DEST"
  echo
}

get-gitlab-public-archive () {
  local NAME=$1
  local DEST=$2
  query $NAME url; local SERVER=$ANS
  query $NAME user; local USER=$ANS
  query $NAME project; local PROJECT=$ANS
  query $NAME sha; local SHA=$ANS

  rm -rf "$DEST"
  echo "Required: $USER/$PROJECT"
  echo "  at $SHA"
  echo "  from $SERVER"

  if [ -f "$SHA.tar.gz" ]; then
    echo "Already downloaded"
  else
    URL="https://$SERVER/$USER/$PROJECT/-/archive/$SHA/$PROJECT-$SHA.tar.gz"
    echo "Fetching from $URL"
    wget -q "$URL"
    mv "$PROJECT-$SHA.tar.gz" "$SHA.tar.gz"
  fi
  echo "Unpacking to folder: $DEST/"
  tar xf "$SHA.tar.gz"
  mv "$PROJECT-$SHA" "$DEST"
  echo
}

get-gitlab-api-archive () {
  local NAME=$1
  local DEST=$2
  query $NAME url; local SERVER=$ANS
  query $NAME project; local PROJECT=$ANS
  query $NAME pid; local PID=$ANS
  query $NAME token; local TOKEN=$ANS
  query $NAME sha; local SHA=$ANS

  rm -rf "$DEST"
  echo "Required: #$PID (aka, $PROJECT)"
  echo "  at $SHA"
  echo "  from $SERVER"
  if [ -f "$SHA.tar.gz" ]; then
    echo "Already downloaded"
  else
    URL="https://$SERVER/api/v4/projects/$PID/repository/archive.tar.gz?sha=$SHA"
    echo "Fetching from $URL using private token $TOKEN"
    curl --header "PRIVATE-TOKEN: $TOKEN" -O "$URL"
    mv "archive.tar.gz" "$SHA.tar.gz"
  fi
  echo "Unpacking to folder: $DEST/"
  tar xf "$SHA.tar.gz"
  mv "$PROJECT-$SHA-$SHA" "$DEST"
  echo
}
