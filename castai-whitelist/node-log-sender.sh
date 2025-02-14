(
(
  set +e



  echo "downloading castai-node-logs-sender binary from https://storage.googleapis.com/castai-node-components/castai-node-logs-sender/releases/0.12.0/castai-node-logs-sender-linux-amd64.tar.gz" >> logs_sender_download_output.log
  curl --fail --silent --show-error --max-time 120 --retry 3 --retry-delay 5 --retry-connrefused https://storage.googleapis.com/castai-node-components/castai-node-logs-sender/releases/0.12.0/castai-node-logs-sender-linux-amd64.tar.gz -o castai-node-logs-sender-linux-amd64.tar.gz 2>> logs_sender_download_output.log
  DOWNLOAD_ERROR=$?

  if [ $DOWNLOAD_ERROR -eq 0 ]; then
    echo "downloading castai-node-logs-sender succeeded" >> logs_sender_download_output.log
    echo "c8941537cdba875abd5bfabefc3878d3fd9cfc7b2b665161bd348e2f846c2619 castai-node-logs-sender-linux-amd64.tar.gz" | sha256sum --check --status 2>> logs_sender_download_output.log
  else
    echo "downloading castai-node-logs-sender failed with error $DOWNLOAD_ERROR" >> logs_sender_download_output.log
  fi

  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
  PREPEND_STRING="{\"logEvents\":[{\"level\": \"info\",\"time\":\"$TIMESTAMP\",\"message\":\""
  CONTENT_STRING=$(awk 1 ORS='\\n' logs_sender_download_output.log)
  APPEND_STRING="\"}]}"

  printf "%s%s%s" "$PREPEND_STRING" "$CONTENT_STRING" "$APPEND_STRING" > logs_sender_download_output.json

  curl --fail --silent --show-error --max-time 120 --retry 3 --retry-delay 5 --retry-connrefused -X POST "https://****/v1/kubernetes/external-clusters/****/nodes/****/logs" -H "X-Api-Key: ****" --data-binary "$(cat logs_sender_download_output.json)" 2> /dev/null
)

mkdir -p bin
BIN_PATH=$PWD/bin/castai-node-logs-sender
tar -xvzf castai-node-logs-sender-linux-amd64.tar.gz
rm castai-node-logs-sender-linux-amd64.tar.gz
mv castai-node-logs-sender $BIN_PATH
chmod +x $BIN_PATH

CONF_PATH=/etc/systemd/system/castai-node-logs-sender.conf

# Proxy vars (if present) below don't have prefix since we want http libraries to pick them automatically in the binary.
cat >${CONF_PATH} <<EOL
CASTAI_API_URL=****
CASTAI_API_KEY=****
CASTAI_CLUSTER_ID=****
CASTAI_NODE_ID=****
CASTAI_PROVIDER="gke"

EOL

echo "# Creating castai-node-logs-sender systemd service"

cat >/etc/systemd/system/castai-node-logs-sender.service <<EOL
[Unit]
Description=CAST.AI service to send node init logs for troubleshooting.
After=network.target

[Service]
Type=simple
EnvironmentFile=${CONF_PATH}
ExecStart=${BIN_PATH}
RemainAfterExit=false
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOL

echo "# Starting castai-node-logs-sender service..."

systemctl --now enable castai-node-logs-sender
) &
