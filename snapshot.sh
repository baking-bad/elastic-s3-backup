#! /bin/sh

set -eo pipefail

# date function is very limited in busybox
function duration2seconds () {
  COUNT=${1//[[:alpha:]]*}
  UNIT=${1##*[[:digit:]]}
  case "${UNIT}" in
    S)
      echo ${COUNT}
      ;;
    M)
      echo $((COUNT*60))
      ;;
    H)
      echo $((COUNT*60*60))
      ;;
    d)
      echo $((COUNT*60*60*24))
      ;;
    w)
      echo $((COUNT*60*60*24*7))
      ;;
    m)
      echo $((COUNT*60*60*24*30))
      ;;
    y)
      echo $((COUNT*60*60*24*30*365))
      ;;
    *)
      echo ${COUNT}
      ;;
  esac
}                                                    
                                                                     
# construct ES_URL                                                   
if [ -n "${ES_USER}" ] ; then                                        
  ES_URL="${ES_SCHEME:-https}://${ES_USER}:${ES_PASSWORD}@${ES_HOST}"
else                                                                 
  ES_URL="${ES_SCHEME:-http}://${ES_HOST}"                           
fi                                                              
if [ -n "${ES_PORT}" ] ; then                     
  ES_URL="${ES_URL}:${ES_PORT}"                   
fi

## -------------- setup repository ---------------
echo "Setup registry"
curl -v -s -k -H 'Content-Type: application/json' -X PUT "${ES_URL}/_snapshot/${ES_REPO}-s3-repository?verify=false&pretty" -d'
{
  "type": "s3",
  "settings": {
    "endpoint": "'${S3_ENDPOINT}'",
    "bucket": "'${S3_BUCKET}'",
    "base_path": "'${ES_REPO}'",
    "client": "default",
    "access_key": "'${S3_ACCESS_KEY_ID}'",
    "secret_key": "'${S3_SECRET_ACCESS_KEY}'"
  }
}'

case "${ES_SNAPSHOT_ACTION:-create}" in
  create)
    ## -------------- create snapshot ---------------
    echo "Create snapshot"
    curl -v -s -k -XPUT "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/${ES_REPO}_$(date +%Y-%m-%d_%H-%M-%S)?pretty&wait_for_completion=true"
    ## -------------- remove old snapshots ---------------
    # refuse to prune old backups if MAX_AGE is not set
    if [ -z "${MAX_AGE}" ] ; then
      echo "You need to set the MAX_AGE environment variable." >&2
      exit 2
    fi
    # prune old snapshots
    MAX_AGE=$(duration2seconds ${MAX_AGE})
    now=$(date +%s);
    older_than=$((now-MAX_AGE))
    echo "Prune old snapshots"
    curl -v -s -k -XGET "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/_all?pretty" | jq -r '.[][] | "\(.start_time) \(.snapshot)" | sub("T"; " ") | sub ("\\..*Z"; "")' | while read date time name ; do
      created=$(date -d "${date} ${time}" +%s);
      if [[ ${created} -lt ${older_than} ]] ; then
        if [ -n "${name}" ] ; then
          curl -s -k -XDELETE "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/${name}?pretty"
        fi
      fi
    # heartbeat
    if [ ! -z "$HEARTBEAT_URI" ]; then
        echo "Send heartbeat signal"
        curl -m 10 --retry 5 $HEARTBEAT_URI
    fi
    done
    ;;
  list)
    ## -------------- list snapshots ---------------
    curl -v -s -k -XGET "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/${ES_SNAPSHOT:-_all}?pretty"
    ;;
  list-indices)
    ## -------------- list snapshot indices ---------------
    # refuse to restore if ES_SNAPSHOT is not set
    if [ -z "${ES_SNAPSHOT}" ] ; then
      echo "You need to set the ES_SNAPSHOT environment variable." >&2
      exit 3
    fi
    curl -v -s -k -XGET "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/${ES_SNAPSHOT}/" | jq -r .snapshots[0].indices[] | tr '\n' ','
    ;;
  restore)
    ## -------------- restore snapshot ---------------
    # refuse to restore if ES_SNAPSHOT is not set
    if [ -z "${ES_SNAPSHOT}" ] ; then
      echo "You need to set the ES_SNAPSHOT environment variable." >&2
      exit 3
    fi
    # by default, restore all indices except kibana
    ES_RESTORE_INDICES="${ES_RESTORE_INDICES:-$(curl -s -k -XGET "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/${ES_SNAPSHOT}/" | jq -r .snapshots[0].indices[] | grep -v kibana | tr '\n' ',')}"
    # refuse to restore if ES_RESTORE_INDICES is blank
    if [ -z "${ES_RESTORE_INDICES}" ] ; then
      echo "You need to set the ES_RESTORE_INDICES environment variable." >&2
      exit 4
    fi
    echo "Restoring indices $ES_RESTORE_INDICES"
    # overwrite existing indices if desired
    if [ "${ES_RESTORE_OVERWRITE_ALL_INDICES}" == "true" ] || [ "${ES_RESTORE_OVERWRITE_ALL_INDICES}" == "1" ] ; then
      for index in ${ES_RESTORE_INDICES//,/ } ; do
        # check if index exists and delete it
        echo "Deleting index ${index}"
        [ "$(curl -qs -XGET "${ES_URL}/${index}" | jq .error)" == "null" ] && curl -s -k -XDELETE "${ES_URL}/${index}"
      done
    elif [ -n "${ES_RESTORE_OVERWRITE_INDICES}" ] ; then
      for index in ${ES_RESTORE_OVERWRITE_INDICES//,/ } ; do
        # check if index exists and delete it
        echo "Deleting index ${index}"
        [ "$(curl -qs -XGET "${ES_URL}/${index}" | jq .error)" == "null" ] && curl -s -k -XDELETE "${ES_URL}/${index}"
      done
    fi
    # restore snapshot
    echo "Restoring snapshot ${ES_SNAPSHOT}"
    curl -v -s -k -XPOST "${ES_URL}/_snapshot/${ES_REPO}-s3-repository/${ES_SNAPSHOT}/_restore?pretty" -H 'Content-Type: application/json' -d'
    {
      "indices": "'${ES_RESTORE_INDICES}'",
      "ignore_unavailable": '${ES_IGNORE_UNAVAILABLE:-true}',
      "include_global_state": '${ES_RESTORE_GLOBAL_STATE:-false}',
      "rename_pattern": "'${ES_RESTORE_RENAME_PATTERN}'",
      "rename_replacement": "'${ES_RESTORE_RENAME_REPLACEMENT}'",
      "include_aliases": '${ES_RESTORE_ALIASES:-false}'
    }'
    ;;
esac