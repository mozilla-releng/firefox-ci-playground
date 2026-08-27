#!/bin/sh
set +x
set -eu
umask 077

task_dir=$1
backup=$2
cert=$3
proof=$4
status=$5
expected_sha=$6
pam_file=/etc/pam.d/su
restored=false

restore_pam() {
  test -r "$backup" || return 1
  backup_sha=$(/usr/bin/sha256sum "$backup" | /usr/bin/cut -d ' ' -f 1)
  test "$backup_sha" = "$expected_sha" || return 1

  /usr/bin/install --owner=root --group=root --mode=0644 "$backup" "$pam_file" || return 1
  restored_sha=$(/usr/bin/sha256sum "$pam_file" | /usr/bin/cut -d ' ' -f 1)
  restored_meta=$(/usr/bin/stat -c '%u:%g:%a' "$pam_file")
  test "$restored_sha" = "$expected_sha" || return 1
  test "$restored_meta" = 0:0:644 || return 1
}

restore_on_exit() {
  if test "$restored" != true; then
    restore_pam >/dev/null 2>&1 || true
  fi
}
trap restore_on_exit EXIT HUP INT TERM

# Restore the system policy before collecting or encrypting any evidence.
restore_pam
restored=true

root_pid=$$
root_uid=$(/usr/bin/id -u)
root_env_entries=$(
  /usr/bin/tr '\000' '\n' <"/proc/$root_pid/environ" |
    /usr/bin/awk 'NF { count++ } END { print count + 0 }'
)

passwd_root_entry=$(
  /usr/bin/awk -F: '$1 == "root" && $3 == "0" { print; exit }' /etc/passwd
)

gw_pid=
for comm_file in /proc/[0-9]*/comm; do
  test -r "$comm_file" || continue
  proc_name=$(/usr/bin/cat "$comm_file" 2>/dev/null || true)
  case "$proc_name" in
    generic-worker*)
      gw_pid=${comm_file#/proc/}
      gw_pid=${gw_pid%/comm}
      break
      ;;
  esac
done

gw_uid=
gw_env_entries=0
gw_cwd=
if test -n "$gw_pid" && test -r "/proc/$gw_pid/status"; then
  gw_uid=$(/usr/bin/awk '/^Uid:/ { print $2; exit }' "/proc/$gw_pid/status")
  gw_cwd=$(/usr/bin/readlink "/proc/$gw_pid/cwd" 2>/dev/null || true)
  gw_env_entries=$(
    /usr/bin/tr '\000' '\n' <"/proc/$gw_pid/environ" |
      /usr/bin/awk 'NF { count++ } END { print count + 0 }'
  )
fi

validation_passed=true
test "$root_uid" = 0 || validation_passed=false
test -n "$passwd_root_entry" || validation_passed=false
test "$root_env_entries" -gt 0 || validation_passed=false
test -n "$gw_pid" || validation_passed=false
test "$gw_uid" = 0 || validation_passed=false
test "$gw_cwd" = / || validation_passed=false
test "$gw_env_entries" -gt 0 || validation_passed=false

generate_proof() {
  printf '%s\n' 'proof-version=1'
  printf '%s\n' 'primitive=generic-worker-archive-mount-proc-self-cwd-pivot'
  printf '%s\n' 'execution-sink=setuid-su-pam-policy-overwrite'
  printf 'pam-original-sha256=%s\n' "$expected_sha"

  printf '%s\n' '[root-identity]'
  /usr/bin/id 2>/dev/null || true
  printf 'uid='; /usr/bin/id -u 2>/dev/null || true
  printf 'gid='; /usr/bin/id -g 2>/dev/null || true
  printf 'user='; /usr/bin/whoami 2>/dev/null || true

  printf '%s\n' '[root-process-status]'
  /usr/bin/cat "/proc/$root_pid/status" 2>/dev/null || true
  printf '%s\n' '[root-process.env]'
  /usr/bin/tr '\000' '\n' <"/proc/$root_pid/environ" 2>/dev/null || true

  printf '%s\n' '[generic-worker-pid]'
  printf '%s\n' "${gw_pid:-not-found}"
  if test -n "$gw_pid"; then
    printf '%s\n' '[generic-worker-process-cwd]'
    printf '%s\n' "${gw_cwd:-not-found}"
    printf '%s\n' '[generic-worker-process-status]'
    /usr/bin/cat "/proc/$gw_pid/status" 2>/dev/null || true
    printf '%s\n' '[generic-worker-process-cmdline]'
    /usr/bin/tr '\000' ' ' <"/proc/$gw_pid/cmdline" 2>/dev/null || true
    printf '\n'
    printf '%s\n' '[generic-worker-process.env]'
    /usr/bin/tr '\000' '\n' <"/proc/$gw_pid/environ" 2>/dev/null || true
  fi

  printf '%s\n' '[/etc/passwd]'
  /usr/bin/cat /etc/passwd 2>/dev/null || true

  printf '%s\n' '[restoration]'
  printf 'sha256=%s\n' "$(/usr/bin/sha256sum "$pam_file" | /usr/bin/cut -d ' ' -f 1)"
  printf 'owner-group-mode=%s\n' "$(/usr/bin/stat -c '%u:%g:%a' "$pam_file")"
}

if ! generate_proof | /usr/bin/openssl cms \
  -encrypt \
  -binary \
  -aes256 \
  -outform DER \
  -out "$proof" \
  "$cert" 2>/dev/null; then
  validation_passed=false
fi
test -s "$proof" || validation_passed=false

proof_sha=unavailable
if test -s "$proof"; then
  proof_sha=$(/usr/bin/sha256sum "$proof" | /usr/bin/cut -d ' ' -f 1)
fi

{
  printf '%s\n' 'proof_version_1=true'
  printf '%s\n' 'pam_restored=true'
  printf 'pam_restored_sha256=%s\n' "$expected_sha"
  printf 'root_uid_0=%s\n' "$(test "$root_uid" = 0 && printf true || printf false)"
  printf 'root_environment_entries=%s\n' "$root_env_entries"
  printf 'passwd_root_entry_found=%s\n' "$(test -n "$passwd_root_entry" && printf true || printf false)"
  printf 'generic_worker_pid_found=%s\n' "$(test -n "$gw_pid" && printf true || printf false)"
  printf 'generic_worker_uid_0=%s\n' "$(test "$gw_uid" = 0 && printf true || printf false)"
  printf 'generic_worker_cwd_root=%s\n' "$(test "$gw_cwd" = / && printf true || printf false)"
  printf 'generic_worker_environment_entries=%s\n' "$gw_env_entries"
  printf 'cms_sha256=%s\n' "$proof_sha"
  printf 'validation_passed=%s\n' "$validation_passed"
} >"$status"

task_uid=$(/usr/bin/stat -c %u "$task_dir")
task_gid=$(/usr/bin/stat -c %g "$task_dir")
/usr/bin/chown "$task_uid:$task_gid" "$status"
/usr/bin/chmod 0600 "$status"
if test -e "$proof"; then
  /usr/bin/chown "$task_uid:$task_gid" "$proof"
  /usr/bin/chmod 0600 "$proof"
fi

trap - EXIT HUP INT TERM
test "$validation_passed" = true
