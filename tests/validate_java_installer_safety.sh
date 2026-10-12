#!/bin/bash
# ==============================================================================
# Script: tests/validate_java_installer_safety.sh
# Purpose: Guard Java installer input, download, and archive handling safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/java.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'validate_inputs()' "${SCRIPT}"
grep -Fq 'download_to_file()' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-oracle.XXXXXX"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-graalvm.XXXXXX"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-maven.XXXXXX"' "${SCRIPT}"
grep -Fq 'mktemp -d "/tmp/java-gradle.XXXXXX"' "${SCRIPT}"
grep -Fq 'JAVA_PATH=$(readlink -f "$(command -v java)")' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)' "${SCRIPT}"; then
    echo "Java installer pipes remote content to a shell." >&2
    exit 1
fi

if grep -Fq 'cd /tmp' "${SCRIPT}"; then
    echo "Java installer still downloads from a shared /tmp working directory." >&2
    exit 1
fi

if grep -Eq 'wget[^\n]*-O[[:space:]]+(oracle-jdk|graalvm)\.tar\.gz' "${SCRIPT}"; then
    echo "Java installer still uses fixed archive names." >&2
    exit 1
fi

if grep -Eq 'ln -sf \$\{?(JDK_DIR|GRAALVM_DIR)\}?' "${SCRIPT}"; then
    echo "Java installer has unquoted JDK/GraalVM symlink paths." >&2
    exit 1
fi

# Maven / Gradle archives must be verified against upstream digests before extract.
grep -Fq 'verify_archive_checksum()' "${SCRIPT}"
grep -Fq 'verify_archive_checksum sha512 "${maven_url}.sha512" "$archive_file"' "${SCRIPT}"
grep -Fq 'verify_archive_checksum sha256 "${gradle_url}.sha256" "$archive_file"' "${SCRIPT}"
grep -Fq 'verify_archive_checksum sha256 "${JDK_URL}.sha256" "$archive_file"' "${SCRIPT}"
grep -Fq 'verify_archive_checksum sha256 "${GRAALVM_URL}.sha256" "$archive_file"' "${SCRIPT}"
if grep -Fq -- '--no-check-certificate' "${SCRIPT}"; then
    echo "Java installer disables TLS certificate verification." >&2
    exit 1
fi
grep -Fq 'ln -sfn "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven' "${SCRIPT}"
grep -Fq 'ln -sfn "/opt/gradle-${GRADLE_VERSION}" /opt/gradle' "${SCRIPT}"
for archive in maven gradle oracle_jdk graalvm; do
    func="install_${archive}"
    body=$(awk -v f="${func}() {" '$0 == f { on = 1 } on { print } on && /^}/ { exit }' "${SCRIPT}")
    verify_line=$(grep -n 'verify_archive_checksum' <<< "${body}" | head -n 1 | cut -d: -f1)
    extract_line=$(grep -nE '(tar -xzf|unzip -q) "\$archive_file"' <<< "${body}" | head -n 1 | cut -d: -f1)
    if [ -z "${verify_line}" ] || [ -z "${extract_line}" ] || [ "${verify_line}" -ge "${extract_line}" ]; then
        echo "Java installer extracts ${archive} before checksum verification." >&2
        exit 1
    fi
done

# Executed checksum behavior with a stubbed wget serving local fixtures.
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/vps_java_checksum.XXXXXX")
trap 'rm -rf -- "${TMP_ROOT}"' EXIT
mkdir -p "${TMP_ROOT}/bin" "${TMP_ROOT}/fixtures"
cat > "${TMP_ROOT}/bin/wget" <<'STUB'
#!/bin/bash
out=""; url=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -O) out="$2"; shift 2 ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
src="${FIXTURE_DIR}/${url##*/}"
[ -f "${src}" ] || exit 8
cp "${src}" "${out}"
STUB
chmod +x "${TMP_ROOT}/bin/wget"

FUNCS="${TMP_ROOT}/funcs.sh"
for f in log download_to_file verify_archive_checksum; do
    awk -v f="${f}() {" '$0 == f { on = 1 } on { print } on && /^}/ { exit }' "${SCRIPT}" >> "${FUNCS}"
done
grep -Fq 'verify_archive_checksum() {' "${FUNCS}"

fx="${TMP_ROOT}/fixtures"
printf 'maven archive bytes\n' > "${TMP_ROOT}/apache-maven-bin.tar.gz"
printf 'gradle archive bytes\n' > "${TMP_ROOT}/gradle-bin.zip"
sha512sum "${TMP_ROOT}/apache-maven-bin.tar.gz" | awk '{print $1}' > "${fx}/good-bare.sha512"
sha512sum "${TMP_ROOT}/apache-maven-bin.tar.gz" | awk '{print toupper($1) "  apache-maven-bin.tar.gz"}' > "${fx}/good-named.sha512"
sha256sum "${TMP_ROOT}/gradle-bin.zip" | awk '{print $1}' > "${fx}/good.sha256"
printf '%0128d\n' 0 > "${fx}/wrong.sha512"
printf 'not-a-hash\n' > "${fx}/garbage.sha512"
sha256sum "${TMP_ROOT}/gradle-bin.zip" | awk '{print $1}' > "${fx}/short.sha512"

run_verify() {
    PATH="${TMP_ROOT}/bin:${PATH}" FIXTURE_DIR="${fx}" LOG_FILE="${TMP_ROOT}/java.log" \
        bash -c 'set -euo pipefail; RED=""; GREEN=""; NC=""; source "$1"; shift; verify_archive_checksum "$@"' \
        _ "${FUNCS}" "$@" >/dev/null 2>&1
}

expect_verify() {
    local want="$1"
    shift
    if run_verify "$@"; then got=ok; else got=fail; fi
    if [ "${got}" != "${want}" ]; then
        echo "verify_archive_checksum $* expected ${want}, got ${got}" >&2
        exit 1
    fi
}

expect_verify ok   sha512 "https://x/good-bare.sha512"  "${TMP_ROOT}/apache-maven-bin.tar.gz"
expect_verify ok   sha512 "https://x/good-named.sha512" "${TMP_ROOT}/apache-maven-bin.tar.gz"
expect_verify ok   sha256 "https://x/good.sha256"       "${TMP_ROOT}/gradle-bin.zip"
expect_verify fail sha512 "https://x/wrong.sha512"      "${TMP_ROOT}/apache-maven-bin.tar.gz"
expect_verify fail sha512 "https://x/garbage.sha512"    "${TMP_ROOT}/apache-maven-bin.tar.gz"
expect_verify fail sha512 "https://x/short.sha512"      "${TMP_ROOT}/apache-maven-bin.tar.gz"
expect_verify fail sha512 "https://x/missing.sha512"    "${TMP_ROOT}/apache-maven-bin.tar.gz"
expect_verify fail md5    "https://x/good.sha256"       "${TMP_ROOT}/gradle-bin.zip"

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--type" <<< "${help_output}"
grep -Fq -- "--version" <<< "${help_output}"

echo "Java installer safety is valid."
