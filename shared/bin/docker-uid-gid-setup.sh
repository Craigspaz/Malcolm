#!/bin/bash

set -e

unset ENTRYPOINT_CMD
unset ENTRYPOINT_ARGS
[ "$#" -ge 1 ] && ENTRYPOINT_CMD="$1" && [ "$#" -gt 1 ] && shift 1 && ENTRYPOINT_ARGS=( "$@" )

# modify the UID/GID for the default user/group (for example, 1000 -> 1001)
usermod --non-unique --uid ${PUID:-${DEFAULT_UID}} ${PUSER}
groupmod --non-unique --gid ${PGID:-${DEFAULT_GID}} ${PGROUP}

# change user/group ownership of any files/directories belonging to the original IDs
if [[ -n ${PUID} ]] && [[ "${PUID}" != "${DEFAULT_UID}" ]]; then
  find / -path /sys -prune -o -path /proc -prune -o -user ${DEFAULT_UID} -exec chown -f ${PUID} "{}" \; || true
fi
if [[ -n ${PGID} ]] && [[ "${PGID}" != "${DEFAULT_GID}" ]]; then
  find / -path /sys -prune -o -path /proc -prune -o -group ${DEFAULT_GID} -exec chown -f :${PGID} "{}" \; || true
fi

# if there are semicolon-separated PUSER_CHOWN entries explicitly specified, chown them too
if [[ -n ${PUSER_CHOWN} ]]; then
  IFS=';' read -ra ENTITIES <<< "${PUSER_CHOWN}"
  for ENTITY in "${ENTITIES[@]}"; do
    chown -R ${PUSER}:${PGROUP} "${ENTITY}" || true
  done
fi

# if there is a trusted CA file or directory specified and openssl is available, handle it
if [[ -n ${PUSER_CA_TRUST} ]] && command -v openssl >/dev/null 2>&1; then
  declare -a CA_FILES
  if [[ -d "${PUSER_CA_TRUST}" ]]; then
    while read -r -d ''; do
      CA_FILES+=("$REPLY")
    done < <(find "${PUSER_CA_TRUST}" -type f -size +31c -print0 2>/dev/null)
  elif [[ -f "${PUSER_CA_TRUST}" ]]; then
    CA_FILES+=("${PUSER_CA_TRUST}")
  fi
  for CA_FILE in "${CA_FILES[@]}"; do
    BASE_CA_NAME="$(basename "$CA_FILE")"
    DEST_FILE=
    CONCAT_FILE=
    HASH_FILE="$(openssl x509 -hash -noout -in "$CA_FILE")".0
    if command -v update-ca-certificates >/dev/null 2>&1; then
      if [[ -d /usr/local/share/ca-certificates ]]; then
        DEST_FILE=/usr/local/share/ca-certificates/"$BASE_CA_NAME"
      elif [[ -d /usr/share/ca-certificates ]]; then
        DEST_FILE=/usr/share/ca-certificates/"$BASE_CA_NAME"
      elif [[ -d /etc/ssl/certs ]]; then
        DEST_FILE==/etc/ssl/certs/"$HASH_FILE"
      fi
    elif command -v update-ca-trust >/dev/null 2>&1; then
      if [[ -d /usr/share/pki/ca-trust-source/anchors ]]; then
        DEST_FILE=/usr/share/pki/ca-trust-source/anchors/"$BASE_CA_NAME"
      elif [[ -d /etc/pki/ca-trust/source/anchors ]]; then
        DEST_FILE=/etc/pki/ca-trust/source/anchors/"$BASE_CA_NAME"
      fi
    else
      if [[ -d /etc/ssl/certs ]]; then
        DEST_FILE=/etc/ssl/certs/"$HASH_FILE"
        CONCAT_FILE=/etc/ssl/certs/ca-certificates.crt
      fi
      if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
        CONCAT_FILE=/etc/ssl/certs/ca-certificates.crt
      elif [[ -f /etc/pki/tls/certs/ca-bundle.crt ]]; then
        CONCAT_FILE=/etc/pki/tls/certs/ca-bundle.crt
      elif [[ -f /usr/share/ssl/certs/ca-bundle.crt ]]; then
        CONCAT_FILE=/usr/share/ssl/certs/ca-bundle.crt
      elif [[ -f /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem ]]; then
        CONCAT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
      fi
    fi
    [[ -n "$DEST_FILE" ]] && ( cp "$CA_FILE" "$DEST_FILE" && chmod 644 "$DEST_FILE" ) || true
    [[ -n "$CONCAT_FILE" ]] && \
      ( echo "" >> "$CONCAT_FILE" && \
        echo "# $BASE_CA_NAME" >> "$CONCAT_FILE" \
        && cat "$CA_FILE" >> "$CONCAT_FILE" ) || true
  done
  command -v update-ca-certificates >/dev/null 2>&1 && update-ca-certificates >/dev/null 2>&1 || true
  command -v update-ca-trust >/dev/null 2>&1 && update-ca-trust extract >/dev/null 2>&1 || true
fi

# determine if we are now dropping privileges to exec ENTRYPOINT_CMD
if [[ "$PUSER_PRIV_DROP" == "true" ]]; then
  EXEC_USER="${PUSER}"
  USER_HOME="$(getent passwd ${PUSER} | cut -d: -f6)"
else
  EXEC_USER="${USER:-root}"
  USER_HOME="${HOME:-/root}"
fi

# execute the entrypoint command specified
su -s /bin/bash -p ${EXEC_USER} << EOF
export USER="${EXEC_USER}"
export HOME="${USER_HOME}"
whoami
id
if [ ! -z "${ENTRYPOINT_CMD}" ]; then
  if [ -z "${ENTRYPOINT_ARGS}" ]; then
    "${ENTRYPOINT_CMD}"
  else
    "${ENTRYPOINT_CMD}" $(printf "%q " "${ENTRYPOINT_ARGS[@]}")
  fi
fi
EOF
