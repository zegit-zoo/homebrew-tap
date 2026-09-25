# zegit-zoo/homebrew-tap

Homebrew formulae for [zegit-zoo](https://github.com/zegit-zoo) tools.

| Formula | Upstream | Description |
| --- | --- | --- |
| `meerkat` | [zegit-zoo/meerkat](https://github.com/zegit-zoo/meerkat) | Knowledge base as a static binary, served over CLI, MCP, and HTTP |

## Install

```sh
brew install zegit-zoo/tap/meerkat
```

Or tap first, then install by bare name:

```sh
brew tap zegit-zoo/tap
brew install meerkat
```

## Upgrade

```sh
brew upgrade meerkat
```

meerkat has a built-in `mk update` self-updater. **Do not use it on a Homebrew
install** — it downloads a release and swaps the binary in place inside the
Cellar, which leaves Homebrew's records pointing at a file whose checksum it no
longer knows. `brew upgrade meerkat` is the supported path here.

meerkat also checks for newer releases in the background and prints a one-line
notice after a command. Silence it with:

```sh
export MEERKAT_NO_UPDATE_CHECK=1
```

## The `mk` alias and its conflict

The formula installs `meerkat` plus `mk`, a symlink to it — `mk` is the
documented short alias, and the two are interchangeable.

homebrew/core ships an unrelated formula, [`mk`](https://formulae.brew.sh/formula/mk)
(the Plan 9 build tool), which installs its own `mk` executable. The two cannot
be installed at the same time, so the formula declares `conflicts_with "mk"`.
If you need both, uninstall one or invoke meerkat by its full name.

## How the formula is verified

This is a **binary** formula: it installs the official release tarballs from
[meerkat's GitHub Releases](https://github.com/zegit-zoo/meerkat/releases). It
does not build from source, and **this tap contains no binaries** — only the
formula, with a sha256 pinned per platform (macOS and Linux, arm64 and amd64).

Those sha256 values are not copied by hand or taken on trust. Each meerkat
release publishes `meerkat_<version>_checksums.txt` alongside a cosign keyless
signature bundle, `meerkat_<version>_checksums.txt.sigstore.json`.
`scripts/update-formula.sh` downloads both and runs:

```sh
cosign verify-blob \
  --certificate-identity-regexp '^https://github.com/zegit-zoo/meerkat/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  --bundle meerkat_<version>_checksums.txt.sigstore.json \
  meerkat_<version>_checksums.txt
```

The identity regexp pins the signature to meerkat's own release workflow,
running on a `v*.*.*` tag, with GitHub Actions as the OIDC issuer. If cosign is
missing or verification fails, the script exits non-zero and the formula is left
untouched — there is no unverified fallback path. Only then are the four
sha256 values read out of the verified file and written into the formula.

## How bumps happen

`.github/workflows/bump.yml` runs `scripts/update-formula.sh latest` on a
schedule (every 6 hours) and on manual `workflow_dispatch` (which takes a `tag`
input, defaulting to `latest`). If the regenerated formula differs from what is
committed, the workflow pushes a `meerkat: bump to vX.Y.Z` commit straight to
`main`; if nothing changed it exits quietly.

`.github/workflows/test.yml` runs `brew audit`, `brew style`, `brew install` and
`brew test` against the tap on both macOS and Linux for every push and pull
request.

## Bumping manually

```sh
scripts/update-formula.sh v0.11.2   # a specific tag
scripts/update-formula.sh latest    # whatever the newest release is
scripts/update-formula.sh           # same as "latest"
```

The script regenerates `Formula/meerkat.rb` in full from a template rather than
patching it, so it is idempotent: re-running it on a tag that is already
committed produces a byte-identical file and no diff. It needs `bash`, `curl`
and `cosign`; `gh` is used to resolve `latest` when available, with the public
GitHub REST API as a fallback.

## License

[Apache-2.0](LICENSE). meerkat itself is Apache-2.0 as well.
