#!/bin/bash

echo "===== Installing jq & curl ====="
sudo apt-get update && sudo apt-get install -y jq curl

echo "===== Executing Test Run ====="
EXECUTE=$(curl -s -k --request POST "$IPADDR/api/rest/1/execute/testrun" \
  --header 'Content-Type: application/json' \
  --header "X-INS-ID: $INSID" \
  --header "X-API-TOKEN: $APITOKEN" \
  --data-raw "{
     \"agentName\": \"$AGENTNAME\",
     \"includeCloudDevice\": \"$INCLUDECLOUDDEVICE\",
     \"includeCloudBrowser\": \"$INCLUDECLOUDBROWSER\",
     \"device\": \"$DEVICENAME\",
     \"projectKey\": \"$PROJECTKEY\",
     \"browser\": \"$BROWSER\",
     \"region\": \"$REGION\",
     \"testRunId\": \"$TESTRUNID\",
     \"cloudAgent\": \"$ISCLOUDAGENT\",
     \"browserVersion\": \"$BROWSERVERSION\",
     \"os\": \"$OS\",
     \"reRunFailedCases\": \"$RUNONLYFAILED\"
  }")

echo "EXECUTE response: $EXECUTE"
value=$(echo $EXECUTE | jq -r '.testRunId')

echo "Test Run ID: $value"

if [ -z "$value" ] || [ "$value" == "null" ]; then
  echo " Failed to retrieve test run ID"
  exit 1
fi

TEST_RUN_ID=$value

echo "===== Monitoring Test Run Status ====="

status=''
agentstatus=''
result=''
count=0
end_time=$(($(date +%s) + 3600)) # 1 hour timeout

while [[ $status != 'COMPLETED' && $agentstatus != 'TERMINATED' && $agentstatus != 'ERROR' && $(date +%s) -lt $end_time ]]; do
    echo "Loop count: $count"
    response=$(curl -s -k --request GET "$IPADDR/api/rest/1/testruns/$TEST_RUN_ID/runstatus" \
      --header 'Content-Type: application/json' \
      --header "X-INS-ID: $INSID" \
      --header "X-API-TOKEN: $APITOKEN")

    echo "API response: $response"

    status=$(echo $response | jq -r '.status')
    result=$(echo $response | jq -r '.result')
    agentstatus=$(echo $response | jq -r '.cloudAgentStatus')

    if [[ $result == 'FAIL' || $status == "null" ]]; then
        echo " Test Failed"
        exit 1
    fi

    sleep 20
    count=$((count+1))
done

echo " Test run completed successfully!"
exit 0
