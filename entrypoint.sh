#! /bin/sh

set -eo pipefail

if [ -z "${S3_ACCESS_KEY_ID}" ]; then
  echo "Please set S3_ACCESS_KEY_ID"
  exit 1
fi

if [ -z "${S3_SECRET_ACCESS_KEY}" ]; then
  echo "Please set S3_SECRET_ACCESS_KEY"
  exit 1
fi

if [ -z "${S3_BUCKET}" ]; then
  echo "Please set S3_BUCKET"
  exit 1
fi

if [ -z "${ES_HOST}" ]; then
  echo "You need to set the ES_HOST environment variable."
  exit 1
fi

if [ -z "${ES_REPO}" ]; then
  echo "You need to set the ES_REPO environment variable."
  exit 1
fi

if [ -z "${SCHEDULE}" ]; then
  sh snapshot.sh
else
  exec go-cron -s "$SCHEDULE" -p 1880 -- /bin/sh ./snapshot.sh
fi