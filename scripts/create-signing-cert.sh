#!/bin/zsh
# Creates the self-signed code-signing identity ("Flyby Local") used to sign release builds.
#
# Why: an ad-hoc signature's identity is the build hash, so after every update macOS
# privacy (TCC) treats Flyby as a different app and the Accessibility grant stops
# applying. A certificate that stays the same keeps the grant across updates.
#
# Run once, store the printed values as GitHub Actions secrets
# (FLYBY_SIGN_CERT_P12, FLYBY_SIGN_CERT_PASSWORD) and keep the .p12 safe: losing it
# means the next release is a new identity (one more permission re-grant).
set -euo pipefail

NAME="${FLYBY_SIGN_IDENTITY:-Flyby Local}"
OUT_DIR="${1:-$PWD/signing}"
PASSWORD=$(/usr/bin/openssl rand -hex 16)
mkdir -p "${OUT_DIR}"

cat > "${OUT_DIR}/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = ${NAME}
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "${OUT_DIR}/cert.cnf" \
  -keyout "${OUT_DIR}/key.pem" -out "${OUT_DIR}/cert.pem"
/usr/bin/openssl pkcs12 -export -inkey "${OUT_DIR}/key.pem" -in "${OUT_DIR}/cert.pem" \
  -name "${NAME}" -passout "pass:${PASSWORD}" -out "${OUT_DIR}/flyby-signing.p12"
rm -f "${OUT_DIR}/key.pem" "${OUT_DIR}/cert.pem" "${OUT_DIR}/cert.cnf"

echo "Created ${OUT_DIR}/flyby-signing.p12 (do not commit it)."
echo
echo "GitHub secrets:"
echo "  FLYBY_SIGN_CERT_PASSWORD = ${PASSWORD}"
echo "  FLYBY_SIGN_CERT_P12      = contents of: base64 -i ${OUT_DIR}/flyby-signing.p12"
echo
echo "Optional, to sign local builds with the same identity:"
echo "  security import ${OUT_DIR}/flyby-signing.p12 -P '${PASSWORD}' -T /usr/bin/codesign"
