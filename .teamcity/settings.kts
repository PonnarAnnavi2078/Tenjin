package TestRun

import jetbrains.buildServer.configs.kotlin.v2024_03.*

version = "2024.03"

project {
    buildType(ExecuteTestRun)
}

object ExecuteTestRun : BuildType({
    name = "Execute Test Run"

    vcs {
        root(DslContext.settingsRoot)
    }

    triggers {
        vcs {
            branchFilter = "+:main"
        }
    }

    params {
        param("IPADDR", "https://yethi-test.tenjinonline.com")
        param("INSID", "yethi-test")
        param("APITOKEN", "NCd+02m6fCBwvAKY88Ud9Bqps36rCWLh2MK6IEGlwOnwhWGX0cdE1g/TgEdrSuO0ImA7Bdi8eu874XIMAfTL8WqQffMTN7eIs535mljZjwiPRIptfxsDWG84Z3Ig0yiMxJ+gNlNjJpwdD5ljkQ7W4S3/+K09y5tlSz/v+UB2/+LahiNcqffzcndj03KAbkMYGlai59wgeS7Goz3EvNHFdB6cIHCVwkCsSFg+lUtPrknemJHkIMsvjxJr1flY8mCi84Waj14J0mPZGtQ+5vmxeJps9J6/rI9KSzh8UiBi7pm1sSx5U8bagRcsbOnJJWMlP6yxd5LqDM4sdA4ycPhOQw==")
        param("AGENTNAME", "Akshay-prod")
        param("INCLUDECLOUDDEVICE", "FALSE")
        param("INCLUDECLOUDBROWSER", "FALSE")
        param("DEVICENAME", "")
        param("PROJECTKEY", "JPD")
        param("BROWSER", "chrome")
        param("REGION", "UTC+05:30")
        param("TESTRUNID", "Test-Run-13381419")
        param("ISCLOUDAGENT", "FALSE")
        param("BROWSERVERSION", "")
        param("OS", "Windows 8.1")
        param("RUNONLYFAILED", "FALSE")
    }

    steps {
        script {
            name = "Install dependencies"
            scriptContent = """
                sudo apt-get update
                sudo apt-get install -y jq curl
            """.trimIndent()
        }

        script {
            name = "Execute test run"
            scriptContent = """
                echo "Starting Execute test run step"
                EXECUTE=$(curl -s -k --request POST "%IPADDR%/api/rest/1/execute/testrun" \
                  --header 'Content-Type: application/json' \
                  --header "X-INS-ID: %INSID%" \
                  --header "X-API-TOKEN: %APITOKEN%" \
                  --data-raw "{
                     \"agentName\": \"%AGENTNAME%\",
                     \"includeCloudDevice\": \"%INCLUDECLOUDDEVICE%\",
                     \"includeCloudBrowser\": \"%INCLUDECLOUDBROWSER%\",
                     \"device\": \"%DEVICENAME%\",
                     \"projectKey\": \"%PROJECTKEY%\",
                     \"browser\": \"%BROWSER%\",
                     \"region\": \"%REGION%\",
                     \"testRunId\": \"%TESTRUNID%\",
                     \"cloudAgent\": \"%ISCLOUDAGENT%\",
                     \"browserVersion\": \"%BROWSERVERSION%\",
                     \"os\": \"%OS%\",
                     \"reRunFailedCases\": \"%RUNONLYFAILED%\"
                   }")
                
                echo "EXECUTE response: $EXECUTE"
                value=$(echo $EXECUTE | jq -r '.testRunId')
                echo "Test Run ID: $value"

                if [ -z "$value" ] || [ "$value" == "null" ]; then
                  echo "Failed to retrieve test run ID"
                  exit 1
                fi

                echo "##teamcity[setParameter name='env.TEST_RUN_ID' value='$value']"
            """.trimIndent()
        }

        script {
            name = "Monitor test run status"
            scriptContent = """
                echo "Starting Monitor test run status step"
                status=''
                agentstatus=''
                result=''
                count=0
                end_time=$(($(date +%s) + 3600)) # One hour timeout
                
                while [[ $status != 'COMPLETED' && $agentstatus != 'TERMINATED' && $agentstatus != 'ERROR' && $(date +%s) -lt $end_time ]]; do
                    echo "Loop count: $count"
                    echo "Fetching status for test run ID: $TEST_RUN_ID"
                    response=$(curl -s -k --request GET "%IPADDR%/api/rest/1/testruns/$TEST_RUN_ID/runstatus" \
                      --header 'Content-Type: application/json' \
                      --header "X-INS-ID: %INSID%" \
                      --header "X-API-TOKEN: %APITOKEN%")

                    echo "API response: $response"
                    status=$(echo $response | jq -r '.status')
                    result=$(echo $response | jq -r '.result')
                    agentstatus=$(echo $response | jq -r '.cloudAgentStatus')
                    echo "Parsed status: $status"
                    echo "Parsed result: $result"
                    echo "Parsed agent status: $agentstatus"
                    sleep 20
                    count=$((count+1))

                    if [[ $result == 'FAIL' || $status == 'null' ]]; then
                        echo "Result status is $result"
                        exit 1
                    else
                        echo "Result status is $result"
                    fi
                done
            """.trimIndent()
        }
    }
})
