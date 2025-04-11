# Configuration guide

This is a library to manage reproducible builds, especially on multi-repository projects.
It enables downloading snapshots from specific commits from several sources (GitHub and any instance of GitLab)
and gathering them all in one archive.
My personal use-case is for artifact submissions for conference papers,
but nothing in this project restricts it to that particular application.

## General steps

The main file is `build.sh`.
If you use a Docker setup, then obviously the `Dockerfile` is also important,
or the `Makefile` if relevant, but this document pertains only to explaining
`build.sh`.

1. **Load the library.**
  This repository provides functions, not scripts. They must be loaded with `. scripts/lib.sh`.
2. **Declare the repositories.**
  For each repository that you need, add one declaration.
  If you need one repository at several different commits, that counts as several repositories
  and will require as many declarations.
3. **Perform the download.**
  You can download the specified commits from the specified repositories to given folders
  in the `data/` directory.
4. **Gather the files for the archive.**
  Finally all relevant files are moved from `data/` (or from the project root)
  to `final/` where the artifact lives in the end.

## Repository declaration

Declaring a repository can be done through the function `declare-repo`.
```sh
declare-repo name-of-repo "
  key1=value1
  key2=value2
  key3=value3
"
```

Essential keys will always include `api` (see next section), `url` (the url of the github instance),
`project` (the name of the project), `sha` (the target commit hash).

More specifically, the `url` should be only the base url without the "https://" of the site.
e.g., `github.com`, `gitlab.com`, `gitlab.mpi-sws.org`, `gricad-gitlab.univ-grenoble-alpes.fr`, etc.

For complete examples, see the sample `build.sh` provided.

### Supported APIs

#### GitHub (public)

Usable for public projects on GitHub.
GitHub provides archives of projects at every commit at the address
`https://github.com/${USER}/${PROJECT}/archive/${SHA}.tar.gz`.
Said archive is downloaded using `wget` as `${SHA}.tar.gz`,
and unpacks to `${PROJECT}-${SHA}/`.

In addition to the standard keys `api=github/public`, `url=github.com` (or a different instance),
`project=${PROJECT}`, `sha=${SHA}`, this API requires additionally `user=${USER}` the namespace of the project.

#### GitLab (public)

Usable for public projects on any GitLab instance (either the official `gitlab.com`, or any organization-ran instance).
If your project is not public, see below.

Similarly but not identically to GitHub, GitLab provides archives at a certain url:
`https://gitlab.com/${USER}/${PROJECT}/-/archive/${SHA}/${PROJECT}-${SHA}.tar.gz`.
For consistency, once this archive is downloaded as `${PROJECT}-${SHA}.tar.gz`,
we rename it to only `${SHA}.tar.gz`.
It unpacks to `${PROJECT}-${SHA}/`

This API requires the same keys as the previous: `api=gitlab/public`, `url=gitlab.com` (or a different instance),
`project=${PROJECT}`, `sha=${SHA}`, and `user=${USER}`.

#### GitLab (access token)

If your project is not public, you can still fetch it through an access token.
Be careful with your handling of access tokens, and see the next section for ways to not expose them on a public repository.

First you should create an access token with permission `read_api`, in role "Maintainer"
(to do so, go to your project's "Settings" > "Access Tokens", and click "Add new token").

This method also requires the "Project ID", which is most GitLab instances is found by clicking the three vertical dots
in the top right, then "Copy project ID: 123456".

GitLab's API makes archives downloadable at the url
`https://gitlab.com/api/v4/projets/${PROJECT_ID}/repository/archive.tar.gz?sha=${SHA}`.
Downloading this requires the header `PRIVATE-TOKEN: ${ACCESS_TOKEN}`.
Unlike the public API, this one downloads to just `archive.tar.gz`,
and unpacks to `${PROJECT}-${SHA}-${SHA}/`.

Using this API requires the usual keys `api=gitlab/apiv4`, `url=gitlab.com` (or a different instance),
`project=${PROJECT}` (project **name**, not project ID), `sha=${SHA}`.
In addition, you must specify `pid=${PROJECT_ID}` and `token=${ACCESS_TOKEN}`.

### Handling secrets

"But wait, I don't want to expose my access token on a repository."
Worry not, you can have granular management of your access tokens.
SHAs too, but that is not as much of a sensitive information.

Say you have a project declaration
```sh
declare-repo gitlab-private-repo "
  api=gitlab/apiv4
  url=gitlab.com
  project=hello-world-private
  pid=68468614
  token=glpat-tbszUGLZ5tPSykUz1vmU
  sha=d6082d5524240387ab9acbb33eb4ff23427ab379
"
```
but (rightfully so), you don't want to expose the token.

The recommended method is as follows:
1. write the token `glpat-tbszUGLZ5tPSykUz1vmU` to the file `SECRETS/TOK_GL_HELLO_WORLD` (use any reasonably descriptive filename);
2. before the declaration, add a line `load-secret TOK_GL_HELLO_WORLD`;
3. replace the actual token with a variable substitution `${TOK_GL_HELLO_WORLD}`;
4. check the `SECRETS/.gitignore` rules, by default your secret file should not be committed.

Concretely, you now should have
```sh
$ cat SECRETS/TOK_GL_HELLO_WORLD
glpat-tbszUGLZ5tPSykUz1vmU
```
```sh
load-secret TOK_GL_HELLO_WORLD
declare-repo gitlab-private-repo "
  api=gitlab/apiv4
  url=gitlab.com
  project=hello-world-private
  pid=68468614
  token=${TOK_GL_HELLO_WORLD}
  sha=d6082d5524240387ab9acbb33eb4ff23427ab379
"
```

The same technique can be applied to SHAs, though because a commit hash is not generally considered as much
of a sensitive piece of information, the pattern `SECRETS/SHA_*` is by default not gitignored.

Ultimately, this is merely the recommended method.
The invocation supports string expansion, so whatever other idea you have so that
`token=$(your command here)` correctly expands to the token will probably work.

## Download

The download phase must be surrounded by
```sh
prepare-download
...
finish-download
```

When in this phase you gain access to the command `unpack`.
```sh
unpack name-of-repo target-folder
```
Where `name-of-repo` must have been declared previously by a `declare-repo`,
and `target-folder` should be the name of a folder that doesn't exist yet.

Concretely, this will
- download the `.tar.gz` archive through one of the APIs described above
  (important: it is not `declare-repo` that performs the download but `unpack`);
- cache it in the `_downloads` folder so that repeated invocations of the
  build script only download each version once;
- unzip it to the stated name, still within `_downloads/`.

It is strongly recommended that you gitignore all of `_downloads/`.

## Archive

The archiving phase must be surrounded by
```sh
prepare-archive
...
finish-archive
```

Both of those commands can optionally take additional arguments.
- `prepare-archive folder-name` will build the archive under `folder-name`,
  instead of the default name `_final`.
  Different invocations should use different `folder-name`s.
  In what follows we assume the default name.
- `finish-archive +tar` will additionally build a compressed `_final.tar.gz`.
- `finish-archive +zip` will additionally build a compressed `_final.zip`.

When in this phase you gain access to the commands below.

- `copy path/to/source`
  Copies an auxiliary file given its path from the root to `_final`.
  It is on purpose that `copy` cannot do more complex logic.
  You will typically use it to copy over `README.md` and `Dockerfile`.
  In fact, `copy Dockerfile` is mandatory if you wish to use `build-docker` later.
  You can always fall back to `cp` if you find `copy` too limiting,
  but don't forget that whenever you are in this phase you have been
  implicitly `cd`'d to `_final/`.
- `compress folder@path/to/ destination`
  This builds `destination.tar.gz` by compressing `path/to/folder` from the relative
  viewpoint of `path/to/`.
  If you want to include the entire project write `project@.`,
  and if you want to include only a subdirectory write `subdir@project/path/to`.
  It goes without saying that `destination` should be distinct between different invocations.
- `build-docker container-name`
  Simply executes `docker build -t container-name`.
  Since the Docker container is built within the context of `final/`,
  you can freely `COPY` using the `destination.tar.gz` names defined
  by `compress` commands.
  This has the convenient consequence that whatever Docker commands you put in your
  `Dockerfile`, the recipient of the archive can execute them in the exact same context.

