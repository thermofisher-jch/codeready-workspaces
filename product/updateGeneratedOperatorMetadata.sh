#!/bin/bash
#
# Copyright (c) 2021 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#

# script to fetch latest operator-bundle image, extract contents, and publish to 
# https://github.com/redhat-developer/codeready-workspaces-images/tree/${MIDSTM_BRANCH}/codeready-workspaces-operator-bundle-generated/

usage () 
{
    echo "Usage: $0 -b [midstream branch] -t [quay tag] -s [sources to update]"
    echo "Example: $0 -b crw-2.y-rhel-8 -t 2.y -s /path/to/github/redhat-developer/codeready-workspaces-images/"
	echo ""
    exit
}

SCRIPT=$(readlink -f "$0"); SCRIPTPATH=$(dirname "$SCRIPT")

DEST_DIR=codeready-workspaces-operator-bundle-generated 
SOURCE_CONTAINER=quay.io/crw/crw-2-rhel8-operator-bundle
# commandline args
while [[ "$#" -gt 0 ]]; do
  case $1 in
    '-s') SOURCE_DIR="$2"; shift 1;; # dir to update from
    '-d') DEST_DIR="$2"; shift 1;; # dir to update to
    '-c') SOURCE_CONTAINER="$2"; shift 1;; # container from which to pull generated CSV data
    '-b') MIDSTM_BRANCH="$2"; shift 1;;
    '-t') CRW_VERSION="$2"; shift 1;;
    '-h') usage;;
  esac
  shift 1
done

if [[ ! ${MIDSTM_BRANCH} ]]; then usage; fi
if [[ ! ${SOURCE_DIR} ]]; then usage; fi

if [[ ! -x ${SCRIPTPATH}/containerExtract.sh ]]; then
    curl -sSLO https://raw.githubusercontent.com/redhat-developer/codeready-workspaces/${MIDSTM_BRANCH}/product/containerExtract.sh
    chmod +x containerExtract.sh
fi

${SCRIPTPATH}/containerExtract.sh ${SOURCE_CONTAINER}:${CRW_VERSION} --delete-before --delete-after || true
rm -fr ${SOURCE_DIR}/${DEST_DIR}
rsync -zrlt /tmp/${SOURCE_CONTAINER//\//-}-${CRW_VERSION}-*/* \
    ${SOURCE_DIR}/${DEST_DIR}/

# CRW-2077 generate a json file with the latest CRW version and CSV versions too
CSV_VERSION_BUNDLE="$(yq -r '.spec.version' ${SOURCE_DIR}/codeready-workspaces-operator-bundle-generated/manifests/codeready-workspaces.csv.yaml)"
echo '{' > ${SOURCE_DIR}/VERSION.json
echo '    "CRW_VERSION": "'${CRW_VERSION}'",'                   >> ${SOURCE_DIR}/VERSION.json
echo '    "CSV_VERSION_BUNDLE": "'${CSV_VERSION_BUNDLE}'"' >> ${SOURCE_DIR}/VERSION.json
echo '}' >> ${SOURCE_DIR}/VERSION.json

# get container suffix number
CRW_VERSION_SUFFIX=$(find /tmp/${SOURCE_CONTAINER//\//-}-${CRW_VERSION}-*/root/buildinfo/ -name "Dockerfile*" | sed -r -e "s#.+-##g")

pushd ${SOURCE_DIR}/ >/dev/null || exit 1
    git add ${DEST_DIR} VERSION.json || true
    git commit -m "[brew] Publish CSV with generated digests from ${SOURCE_CONTAINER}:${CRW_VERSION_SUFFIX}" ${DEST_DIR} VERSION.json || true
    git pull origin "${MIDSTM_BRANCH}" || true
    git push origin "${MIDSTM_BRANCH}"
popd >/dev/null || true

# cleanup
rm -fr /tmp/${SOURCE_CONTAINER//\//-}-${CRW_VERSION}-*
