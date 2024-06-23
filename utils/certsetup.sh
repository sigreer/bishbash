#!/bin/bash
sshpass -p "${SSH_PASS} scp -r ${SSH_USER}@${SSH_HOST}:${SSH_HOST_BASEDIR}/certificates/* ${LOCAL_CERTDIR}"

chmod 400 "${LOCAL_CERTDIR}/*"
cp "${LOCAL_CERTDIR}/CAs/*" "/usr/local/share/ca-certificates/"
update-ca-certificates
