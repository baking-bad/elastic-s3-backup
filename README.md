# elastic-s3-backup

Yet another variation based on https://github.com/treksler/elasticsearch-snapshot-s3, supporting DO Spaces, hearbeats, and freshness checks.

## Usage
```yaml
backuper:
  image: ghcr.io/baking-bad/elastic-s3-backup:master
  environment:
    - S3_ENDPOINT=${S3_ENDPOINT}
    - S3_ACCESS_KEY_ID=${S3_ACCESS_KEY_ID}
    - S3_SECRET_ACCESS_KEY=${S3_SECRET_ACCESS_KEY}
    - S3_BUCKET=${S3_BUCKET}
    - ES_HOST=${ES_HOST}
    - ES_REPO=${ES_REPO}
    - ES_SNAPSHOT_ACTION=${ES_SNAPSHOT_ACTION:-create}
    - HEARTBEAT_URI=${HEARTBEAT_URI}
    - SCHEDULE=${SCHEDULE}
```

### Digital Ocean
`S3_ENDPOINT` is your space endpoint (not space address)  
`S3_BUCKET` is space name

### Schedule
Use CRON expression generator.  
If `SCHEDULE` is empty, a one-time snapshot will be made.

### Heartbeat
`HEARTBEAT_URI` is optional