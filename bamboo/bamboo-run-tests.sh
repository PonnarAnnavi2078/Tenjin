#!/bin/bash

# ===== User Configurable Variables =====
IPADDR="https://yethi-test.tenjinonline.com"
INSID="yethi-test"
APITOKEN="PTBObDiIJfEjGjQ6a8B+czxjxGVRlRrOO3Tgxj3csQPwz7mLSzAJbLtvEKnZfhpgomYv7bM0F04EpcfjQ30ce/JspffvHKmHqZ8oX5oAQXW0Drwbx9GJeBrc0vdK27/HfxOEk7KQkR1DxbGpcObx21wYKs/Ufhv0VLXdTbVUYqVfjDSbEL36GumM0Xz2ElkG5y7iKt0weZBAlLbQGPUDOWwgTIPBQTrnE51iQKpp7FLNYKmpmczfm7a9GcNFcGh2KbwqlN8Bya3q4aWdKqGqMWjdcTfsnEhfqBXmYb7i/1/N0aDVZKuXg/50bzbNwURx5Cp3oqr7fYeodle3Rgw+jw=="
AGENTNAME="Ponnar-agent"
INCLUDECLOUDDEVICE=false
INCLUDECLOUDBROWSER=false
DEVICENAME=""
PROJECTKEY="JPD"
BROWSER="CHROME"
REGION="UTC+05:30"
TESTRUNID="Test-Run-13381419"
ISCLOUDAGENT=false
BROWSERVERSION="latest"
OS="Windows 11"
RUNONLYFAILED=false

echo "===== Validating mandatory fields ====="
if [[ -z "$IPADDR" || -z "$INSID" || -z "$APITOKEN" ]]; then
  echo " ERROR: IPADDR / INSID / APITOKEN must not be empty"
  exit 1
fi

# ===== Ensure jq & curl available =====
echo "===== Checking jq & curl ====="
if ! command -v curl >/dev/null; then
  echo "Installing curl..."
  sudo apt-get update && sudo apt-get install -y curl || true
fi

if ! command -v jq >/dev/null; then
  echo "Installing jq..."
  curl -L -o jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  chmod +x jq
  sudo mv jq /usr/local/bin/
fi

# ===== Execute Test Run =====
echo "===== Executing Test Run API ====="
EXECUTE=$(curl -s -k --fail \
  --request POST "${IPADDR}/api/rest/1/execute/testrun" \
  --header 'Content-Type: application/json' \
  --header "X-INS-ID: ${INSID}" \
  --header "X-API-TOKEN: ${APITOKEN}" \
  --data-raw "{
     \"agentName\": \"${AGENTNAME}\",
     \"includeCloudDevice\": ${INCLUDECLOUDDEVICE},
     \"includeCloudBrowser\": ${INCLUDECLOUDBROWSER},
     \"device\": \"${DEVICENAME}\",
     \"projectKey\": \"${PROJECTKEY}\",
     \"browser\": \"${BROWSER}\",
     \"region\": \"${REGION}\",
     \"testRunId\": \"${TESTRUNID}\",
     \"cloudAgent\": ${ISCLOUDAGENT},
     \"browserVersion\": \"${BROWSERVERSION}\",
     \"os\": \"${OS}\",
     \"reRunFailedCases\": ${RUNONLYFAILED}
  }")

echo "EXECUTE response:"
echo "$EXECUTE"

TEST_RUN_ID=$(echo "$EXECUTE" | jq -r '.testRunId')

if [[ -z "$TEST_RUN_ID" || "$TEST_RUN_ID" == "null" ]]; then
  echo " ERROR: Test Run ID not received — check ProjectKey/TestRunId/API Token"
  exit 1
fi

echo " Test Run Started — ID: $TEST_RUN_ID"

# ===== Monitor Test Run Status =====
echo "===== Monitoring Test Run Status ====="
status="STARTED"
result=""
agentstatus=""
count=0
timeout=$(( $(date +%s) + 3600 )) # 1-hour timeout

while [[ $(date +%s) -lt $timeout ]]; do
  echo "⏳ Checking... (iteration $count)"

  response=$(curl -s -k \
    --request GET "${IPADDR}/api/rest/1/testruns/${TEST_RUN_ID}/runstatus" \
    --header 'Content-Type: application/json' \
    --header "X-INS-ID: ${INSID}" \
    --header "X-API-TOKEN: ${APITOKEN}")

  echo "Response: $response"

  status=$(echo "$response" | jq -r '.status')
  result=$(echo "$response" | jq -r '.result')
  agentstatus=$(echo "$response" | jq -r '.cloudAgentStatus')

  if [[ "$result" == "FAIL" ]]; then
    echo " Test Result: FAILED"
    exit 1
  fi

  if [[ "$status" == "COMPLETED" ]]; then
    echo " Test Completed Successfully"
    echo "Result: $result"
    exit 0
  fi

  if [[ "$agentstatus" == "TERMINATED" || "$agentstatus" == "ERROR" ]]; then
    echo " Cloud Agent Issue: $agentstatus"
    exit 1
  fi

  sleep 20
  count=$((count+1))
done

echo " Timeout after 1 hour — test still running"
exit 1
