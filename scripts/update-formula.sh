#!/usr/bin/env bash
#
# update-formula.sh — regenerate Formula/meerkat.rb for a given meerkat release.
#
# Usage:
#   scripts/update-formula.sh [TAG]
#
#   TAG   a release tag such as v0.11.1, or "latest" (default) to resolve
#         the newest release from GitHub.
#
# The sha256 values are never taken on trust: the script downloads
# meerkat_<version>_checksums.txt together with its cosign keyless sigstore
# bundle and refuses to continue unless cosign verifies the bundle against the
# meerkat release workflow's certificate identity. The formula is then
# regenerated in full from the template below, so repeated runs on the same tag
# produce a byte-identical file (idempotent).
#
# Runs on macOS and on ubuntu-latest; needs bash, curl, cosign and (optionally)
# the gh CLI for resolving "latest".

set -euo pipefail

REPO="zegit-zoo/meerkat"
IDENTITY_REGEXP='^https://github.com/zegit-zoo/meerkat/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$'
OIDC_ISSUER="https://token.actions.githubusercontent.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FORMULA="${TAP_ROOT}/Formula/meerkat.rb"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}
info() { printf '==> %s\n' "$*" >&2; }

# --- preflight ---------------------------------------------------------------

command -v curl >/dev/null 2>&1 || die "curl is required but not installed"

if ! command -v cosign >/dev/null 2>&1
then
  die "cosign is required but not installed.
Install it with 'brew install cosign' or via sigstore/cosign-installer in CI.
Refusing to update the formula without verifying the release signature."
fi

# --- resolve the tag ---------------------------------------------------------

TAG="${1:-latest}"

if [[ "${TAG}" == "latest" ]]
then
  info "resolving latest release of ${REPO}"
  if command -v gh >/dev/null 2>&1
  then
    TAG="$(gh release view --repo "${REPO}" --json tagName --jq .tagName)"
  else
    # Fall back to the public REST API; no authentication needed.
    TAG="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
      sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
      head -n 1)"
  fi
  [[ -n "${TAG}" ]] || die "could not resolve the latest release tag"
fi

# Accept both "v0.11.1" and "0.11.1"; normalise to both forms.
VERSION="${TAG#v}"
TAG="v${VERSION}"

case "${VERSION}" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) die "unexpected version '${VERSION}' (from tag '${TAG}'); expected X.Y.Z" ;;
esac

info "target release: ${TAG} (version ${VERSION})"

# --- download the checksums and its signature --------------------------------

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

CHECKSUMS="meerkat_${VERSION}_checksums.txt"
BUNDLE="${CHECKSUMS}.sigstore.json"
BASE_URL="https://github.com/${REPO}/releases/download/${TAG}"

for asset in "${CHECKSUMS}" "${BUNDLE}"
do
  info "downloading ${asset}"
  curl -fsSL --retry 3 --retry-delay 2 \
    -o "${WORKDIR}/${asset}" "${BASE_URL}/${asset}" ||
    die "failed to download ${asset} from ${BASE_URL}"
done

# --- verify the signature (hard gate) ----------------------------------------

info "verifying ${CHECKSUMS} with cosign"
if ! cosign verify-blob \
   --certificate-identity-regexp "${IDENTITY_REGEXP}" \
   --certificate-oidc-issuer "${OIDC_ISSUER}" \
   --bundle "${WORKDIR}/${BUNDLE}" \
   "${WORKDIR}/${CHECKSUMS}" >&2
then
  die "cosign verification FAILED for ${CHECKSUMS} — refusing to update the formula"
fi
info "cosign verification OK"

# --- extract the four sha256 values ------------------------------------------

# Anchored so that neither the .sbom.json entries nor the separate
# meerkat-bootstrap_* artifacts can be matched by accident.
sha_for() {
  local os="$1" arch="$2" file line count
  file="meerkat_${VERSION}_${os}_${arch}.tar.gz"
  line="$(grep -E "^[0-9a-f]{64}  ${file}\$" "${WORKDIR}/${CHECKSUMS}" || true)"
  [[ -n "${line}" ]] || die "no sha256 entry for ${file} in ${CHECKSUMS}"
  count="$(printf '%s\n' "${line}" | wc -l | tr -d ' ')"
  [[ "${count}" == "1" ]] || die "multiple sha256 entries for ${file} in ${CHECKSUMS}"
  printf '%s\n' "${line%% *}"
}

SHA_DARWIN_ARM64="$(sha_for darwin arm64)"
SHA_DARWIN_AMD64="$(sha_for darwin amd64)"
SHA_LINUX_ARM64="$(sha_for linux arm64)"
SHA_LINUX_AMD64="$(sha_for linux amd64)"

# --- regenerate the formula ---------------------------------------------------

mkdir -p "$(dirname "${FORMULA}")"

# The template is quoted ('TEMPLATE') so that nothing inside it — backticks,
# #{...}, $ — is touched by the shell. Only the __PLACEHOLDER__ tokens are
# substituted, which keeps the output a pure function of (version, shas).
cat <<'TEMPLATE' | sed \
  -e "s|__VERSION__|${VERSION}|g" \
  -e "s|__TAG__|${TAG}|g" \
  -e "s|__SHA_DARWIN_ARM64__|${SHA_DARWIN_ARM64}|g" \
  -e "s|__SHA_DARWIN_AMD64__|${SHA_DARWIN_AMD64}|g" \
  -e "s|__SHA_LINUX_ARM64__|${SHA_LINUX_ARM64}|g" \
  -e "s|__SHA_LINUX_AMD64__|${SHA_LINUX_AMD64}|g" \
  >"${FORMULA}"
# typed: false
# frozen_string_literal: true

# This file is generated by scripts/update-formula.sh — do not edit by hand.
# The sha256 values below come from a cosign-verified checksums file.
class Meerkat < Formula
  desc "Knowledge base as a static binary, served over CLI, MCP, and HTTP"
  homepage "https://github.com/zegit-zoo/meerkat"
  license "Apache-2.0"
  # No explicit `version`: Homebrew scans 0.11.1-style versions out of the
  # release URLs below, and `brew audit --strict` rejects restating it.

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/zegit-zoo/meerkat/releases/download/__TAG__/meerkat___VERSION___darwin_arm64.tar.gz"
      sha256 "__SHA_DARWIN_ARM64__"
    end

    on_intel do
      url "https://github.com/zegit-zoo/meerkat/releases/download/__TAG__/meerkat___VERSION___darwin_amd64.tar.gz"
      sha256 "__SHA_DARWIN_AMD64__"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/zegit-zoo/meerkat/releases/download/__TAG__/meerkat___VERSION___linux_arm64.tar.gz"
      sha256 "__SHA_LINUX_ARM64__"
    end

    on_intel do
      url "https://github.com/zegit-zoo/meerkat/releases/download/__TAG__/meerkat___VERSION___linux_amd64.tar.gz"
      sha256 "__SHA_LINUX_AMD64__"
    end
  end

  conflicts_with "mk", because: "both install a `mk` executable"

  def install
    bin.install "meerkat"
    bin.install_symlink "meerkat" => "mk"
    doc.install "README.md", "LICENSE", "NOTICE", "THIRD-PARTY-LICENSES.txt"
    # Default shells (bash, zsh, fish); `meerkat completion <shell>` is a
    # cobra subcommand, which is the default :none parameter format.
    generate_completions_from_executable(bin/"meerkat", "completion")
  end

  def caveats
    <<~EOS
      `mk` is installed as a symlink to `meerkat`; the two are interchangeable.
      It conflicts with the `mk` formula (the Plan 9 build tool), which ships an
      unrelated `mk` executable.

      Use `brew upgrade meerkat` to update. The built-in `mk update`
      self-updater is not for Homebrew installs: releases after 0.11.1 refuse to
      run it from the Cellar, and 0.11.1 would swap the binary in place behind
      Homebrew's back.

      meerkat checks for new releases in the background and prints a one-line
      notice. To silence it:
        export MEERKAT_NO_UPDATE_CHECK=1
    EOS
  end

  test do
    ENV["MEERKAT_NO_UPDATE_CHECK"] = "1"

    assert_match version.to_s, shell_output("#{bin}/meerkat version")
    assert_match "knowledge-base", shell_output("#{bin}/mk --help")
  end
end
TEMPLATE

info "wrote ${FORMULA} for ${TAG}"
