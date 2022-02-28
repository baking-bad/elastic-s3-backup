FROM  alpine:3.10
ENV   ES_HOST='' \
      ES_PORT='' \
      ES_SCHEME='http' \
      ES_REPO='' \
      ES_REPO_FILE='' \
      ES_USER='' \
      ES_USER_FILE='' \
      ES_PASSWORD='' \
      ES_PASSWORD_FILE='' \
      S3_ACCESS_KEY_ID='' \
      S3_SECRET_ACCESS_KEY='' \
      S3_DEFAULT_REGION='' \
      S3_BUCKET='' \
      S3_IAM_ROLE='' \
      S3_ENDPOINT='' \
      S3_S3V4='no' \
      SCHEDULE='' \
      MAX_AGE='10y'
RUN   apk update \
      && apk add --no-cache \
          curl \
          jq \
          py-pip \
          gcc \
          libc-dev \
          python2-dev \
          libffi-dev \
          libressl-dev \
          dumb-init \
      && curl -L --insecure https://github.com/odise/go-cron/releases/download/v0.0.7/go-cron-linux.gz | zcat > /usr/local/bin/go-cron \
      && chmod u+x /usr/local/bin/go-cron \
      && pip install awscurl

COPY entrypoint.sh .
COPY snapshot.sh .

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["sh", "entrypoint.sh"]