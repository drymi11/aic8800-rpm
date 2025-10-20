#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'USAGE'
Usage: scripts/install-rpm.sh [options]

Build (and optionally install) an RPM package containing the AIC8800 firmware
and RF test utilities.

Options:
  --version <version>   Override the upstream version parsed from debian/changelog.
  --release <release>   Override the RPM release number (default comes from changelog).
  --output-dir <dir>    Directory to place the resulting RPMs (default: dist/rpm).
  --keep-workdir        Do not delete the temporary rpmbuild workspace on success.
  --install             Install the generated RPM with sudo rpm -Uvh.
  -h, --help            Display this help message.
USAGE
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

VERSION_OVERRIDE=""
RELEASE_OVERRIDE=""
OUTPUT_DIR=""
KEEP_WORKDIR=false
INSTALL_AFTER_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --release)
            RELEASE_OVERRIDE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --keep-workdir)
            KEEP_WORKDIR=true
            shift
            ;;
        --install)
            INSTALL_AFTER_BUILD=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help >&2
            exit 1
            ;;
    esac
done

if ! command -v git >/dev/null 2>&1; then
    echo "git is required to create the source archive" >&2
    exit 1
fi

if ! command -v rpmbuild >/dev/null 2>&1; then
    echo "rpmbuild is required but was not found in PATH" >&2
    exit 1
fi

debian_version=$(sed -n '1s/.*(\(.*\)).*/\1/p' "${PROJECT_ROOT}/debian/changelog" || true)
if [[ -z "${debian_version}" ]]; then
    echo "Unable to determine upstream version from debian/changelog" >&2
    exit 1
fi

if [[ -n "${VERSION_OVERRIDE}" ]]; then
    upstream_version="${VERSION_OVERRIDE}"
else
    upstream_version="${debian_version%-*}"
    if [[ "${upstream_version}" == "${debian_version}" ]]; then
        # No Debian revision suffix, use the parsed value directly
        upstream_version="${debian_version}"
    fi
fi

if [[ -n "${RELEASE_OVERRIDE}" ]]; then
    rpm_release="${RELEASE_OVERRIDE}"
else
    if [[ "${debian_version}" == "${upstream_version}" ]]; then
        rpm_release="1"
    else
        rpm_release="${debian_version##*-}"
    fi
fi

rpm_version="${upstream_version//+/.}"
rpm_version="${rpm_version//~/_}"

if [[ -z "${OUTPUT_DIR}" ]]; then
    OUTPUT_DIR="${PROJECT_ROOT}/dist/rpm"
fi
mkdir -p "${OUTPUT_DIR}"

workdir=$(mktemp -d)
trap 'if [[ "${KEEP_WORKDIR}" != "true" ]]; then rm -rf "${workdir}"; else echo "Working directory kept at ${workdir}"; fi' EXIT

for dir in BUILD BUILDROOT RPMS SOURCES SPECS SRPMS; do
    mkdir -p "${workdir}/${dir}"
done

archive_name="aic8800-${rpm_version}.tar.gz"
( cd "${PROJECT_ROOT}" && git archive --format=tar.gz --prefix=aic8800-${rpm_version}/ HEAD ) > "${workdir}/SOURCES/${archive_name}"

spec_path="${workdir}/SPECS/aic8800.spec"
cp "${PROJECT_ROOT}/packaging/aic8800.spec" "${spec_path}"

rpmbuild \
    --define "_topdir ${workdir}" \
    --define "repo_root ${PROJECT_ROOT}" \
    --define "rpm_version ${rpm_version}" \
    --define "rpm_release ${rpm_release}" \
    -bb "${spec_path}"

find "${workdir}/RPMS" -type f -name '*.rpm' -exec cp -v {} "${OUTPUT_DIR}" \;
find "${workdir}/SRPMS" -type f -name '*.src.rpm' -exec cp -v {} "${OUTPUT_DIR}" \;

if [[ "${INSTALL_AFTER_BUILD}" == "true" ]]; then
    rpm_file=$(find "${OUTPUT_DIR}" -maxdepth 1 -type f -name 'aic8800-*.rpm' | sort | tail -n1)
    if [[ -z "${rpm_file}" ]]; then
        echo "No RPM found to install" >&2
        exit 1
    fi
    echo "Installing ${rpm_file}" >&2
    sudo rpm -Uvh "${rpm_file}"
fi

echo "RPM artifacts are available in ${OUTPUT_DIR}"
