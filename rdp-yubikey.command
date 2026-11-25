#!/bin/zsh
# RDP from macOS to a Windows PC with FIDO2 security key (YubiKey) redirection,
# using FreeRDP's [MS-RDPEWA] WebAuthn virtual channel (/dvc:rdpewa).
#
# Asks for the username (the last one is remembered) and the password (shown as *).
# Credentials are handed to FreeRDP over a file descriptor (/args-from:fd:3), never
# on the command line, so they don't show up in `ps`. Settings: config.local.
setopt err_return no_unset pipe_fail

D=${0:A:h}
CONFIG=$D/config.local
USERFILE=$D/.last-user
LOG=$D/rdp-yubikey.log
FREERDP=${FREERDP:-$(command -v sdl-freerdp || print /opt/homebrew/bin/sdl-freerdp)}

die() { print -u2 -- "Error: $*"; exit 1 }

[[ -x $FREERDP ]] || die "sdl-freerdp not found. Install it with: brew install freerdp"
[[ -f $CONFIG ]] || die "$CONFIG missing. Copy config.example to config.local and set HOST."

HOST= CERT_FP= CERT_NAME=
EXTRA_ARGS=()
source "$CONFIG"
[[ -n $HOST ]] || die "HOST is not set in $CONFIG"

# First connect: show the host's certificate and pin it after confirmation.
if [[ -z $CERT_FP ]]; then
  target=$HOST; [[ $target == *:* ]] || target=$target:3389
  # s_client exits non-zero even when it got the certificate, so check the output instead.
  pem=$( (openssl s_client -connect "$target" </dev/null 2>/dev/null || true) | openssl x509 2>/dev/null || true)
  [[ $pem == *"BEGIN CERTIFICATE"* ]] || die "could not read the RDP certificate from $target"
  fp=$(print -r -- "$pem" | openssl x509 -noout -fingerprint -sha256 | sed 's/.*=//' | tr 'A-F' 'a-f')
  cn=$(print -r -- "$pem" | openssl x509 -noout -subject | sed -E 's/.*CN ?= ?//; s/[,/].*//')
  print "Certificate of $target:"
  print "  Name:    $cn"
  print "  SHA-256: $fp"
  print -n "Trust this certificate and save it to config.local? [y/N] "
  read -r answer
  [[ $answer == [yY]* ]] || die "certificate not trusted"
  CERT_FP=$fp CERT_NAME=$cn
  sed -i '' -e "s|^CERT_FP=.*|CERT_FP=$fp|" -e "s|^CERT_NAME=.*|CERT_NAME=$cn|" "$CONFIG"
  grep -q '^CERT_FP=' "$CONFIG" || print "CERT_FP=$fp" >> "$CONFIG"
  grep -q '^CERT_NAME=' "$CONFIG" || print "CERT_NAME=$cn" >> "$CONFIG"
fi
cert="/cert:${CERT_NAME:+name:$CERT_NAME,}fingerprint:sha256:$CERT_FP"

last=$(cat "$USERFILE" 2>/dev/null || true)
print -n "Username${last:+ [$last]}: "
read -r user
user=${user:-$last}
[[ -n $user ]] || die "no username given"
print -r -- "$user" > "$USERFILE"

print -n "Password: "
pw=""
while read -rs -u0 -k1 c; do
  case $c in
    $'\n'|$'\r') break ;;
    $'\x7f'|$'\b') if [[ -n $pw ]]; then pw=${pw[1,-2]}; print -n $'\b \b'; fi ;;
    $'\x03') print; exit 130 ;;
    *) pw+=$c; print -n "*" ;;
  esac
done
print

# One argument per line; printf is a zsh builtin, so nothing appears in ps.
# script(1) gives FreeRDP a pty (prompts like the FIDO PIN stay visible) and logs.
script -q "$LOG" "$FREERDP" /args-from:fd:3 3< <(
  printf '%s\n' "/v:$HOST" "/u:$user" "/p:$pw" "$cert" /dvc:rdpewa \
    "/log-filters:com.freerdp.channels.rdpewa*:DEBUG" "${EXTRA_ARGS[@]}"
)
