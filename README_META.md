# Artifact evaluation template

## Files

- `README.md` is the root readme of the artifact.
  This one (`README_META.md`) on the other hand is private.
- `Dockerfile` is included for reference
- the source code of any archives declared in `build.sh`, and their `sha256sum`.

## Building the Docker container

You need to have [Docker](https://docs.docker.com/get-started/get-docker/) installed.

Then you can simply run `./build.sh`.
It will take a while the first time, but Docker does enough caching that this is not a problem.
The script assumes that you also have `curl`, `wget`, `tar`.
It builds the `data/` folder by fetching LoLA and ParCoSys from specific commit hashes.

Once `build.sh` has finished executed,
you can switch to `README.md` for further instructions.

The final artifact is found in `final/`.

