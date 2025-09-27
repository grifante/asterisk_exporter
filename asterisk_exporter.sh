#!/bin/bash

SCRAPE_INTERVAL=10
METRIC_FILE="/opt/prometheus/custom-metrics/asterisk.prom"
TEMP_FILE=$(mktemp)

process_labels() {
	labels="{"

  while [ $# -gt 1 ]; do
    name="$1"
    value="$2"
    labels+="$name=\"$value\"," 
    shift 2
  done

	labels="${labels%,}"
	labels+="}"

	echo "$labels"
}

append_gauge_header () {
  local metric="$1"
  echo "# TYPE $metric gauge" >> $TEMP_FILE
}

append_gauge () {
  local metric="$1"
  local value="$2"

  shift 2
	local labels=$(process_labels "$@")

  echo "$metric$labels $value" >> $TEMP_FILE
}

append_counter() {
    echo "# Type $1 counter" >> $TEMP_FILE
    echo "$1 $2" >> $TEMP_FILE
}

publish () {
  mv -f $TEMP_FILE $METRIC_FILE
}

collect () {
  local x=$(asterisk -rx 'core show uptime seconds')
  AST_UPTIME_SEC=$(echo $x | cut -d' ' -f3)
  AST_LAST_RELOAD_SEC=$(echo $x | cut -d' ' -f6)

  append_counter "asterisk_uptime_seconds" $AST_UPTIME_SEC
  append_counter "asterisk_last_core_reload_seconds" $AST_LAST_RELOAD_SEC

  x=$(asterisk -rx 'core show channels' | tail -3)
  AST_ACTIVE_CHANNELS=$(echo $x | cut -d' ' -f1)
  AST_ACTIVE_CALLS=$(echo $x | cut -d' ' -f4)
  AST_CALLS_PROCESSED=$(echo $x | cut -d' ' -f7)

  append_gauge_header "asterisk_active_channels"
  append_gauge "asterisk_active_channels" $AST_ACTIVE_CHANNELS

  append_gauge_header "asterisk_active_calls"
  append_gauge "asterisk_active_calls" $AST_ACTIVE_CALLS
  
  append_counter "asterisk_calls_processed" $AST_CALLS_PROCESSED

  ### asterisk_core_threads 
  append_gauge_header "asterisk_core_threads"

  AST_THREADS=$(asterisk -rx 'core show threads' | head -n -1 | cut -d' ' -f3 | sort | uniq -c | awk '{$1=$1; print $0}')
  while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    thread=$(echo "$line" | awk '{$1=""; sub(/^ +/, ""); print}')
    append_gauge "asterisk_core_threads" "$count" "thread" "$thread"
  done <<< "$AST_THREADS"
  ###

  AST_EXTEN_UNKNOWN_STATUS=$(asterisk -rx 'sip show peers' | grep -P '^\d{3,}.*UNKNOWN\s' | wc -l)
  append_gauge_header "asterisk_exten_status_unknown"
  append_gauge "asterisk_exten_status_unknown" $AST_EXTEN_UNKNOWN_STATUS

  AST_EXTEN_QUALIFIED_STATUS=$(asterisk -rx 'sip show peers' | grep -P '^\d{3,}.*OK\s\(\d+' | wc -l)
  append_gauge_header  "asterisk_exten_status_qualified"
  append_gauge  "asterisk_exten_status_qualified" $AST_EXTEN_QUALIFIED_STATUS
}

while true
do
 collect
 publish
 sleep $SCRAPE_INTERVAL
 TEMP_FILE=$(mktemp)
done