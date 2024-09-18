#!/bin/bash

# Define the server URL
SERVER_URL="https://geo.example.com/location"

# Path to the geoclue agent
AGENT_PATH="/usr/lib/geoclue-2.0/demos/agent"

# Start the geoclue agent in the background
$AGENT_PATH &
AGENT_PID=$!

# Allow the agent to start
sleep 2

# Run the geoclue2 'where-am-i' command and capture the output
LOCATION_OUTPUT=$(/usr/lib/geoclue-2.0/demos/where-am-i 2>&1)

# Check if the command was successful
if [ $? -ne 0 ]; then
    echo "Failed to run geoclue2 command."
    kill $AGENT_PID
    wait $AGENT_PID 2>/dev/null
    exit 1
fi

echo "$LOCATION_OUTPUT"

# Extract the last block of location data by splitting on "New location:"
LAST_BLOCK=$(echo "$LOCATION_OUTPUT" | awk -v RS='New location:' 'NR>1 {last=$0} END {print last}')

# Extract latitude, longitude, and accuracy
LATITUDE=$(echo "$LAST_BLOCK" | grep -m 1 "Latitude:" | awk '{print $2}' | sed 's/°//')
LONGITUDE=$(echo "$LAST_BLOCK" | grep -m 1 "Longitude:" | awk '{print $2}' | sed 's/°//')
ACCURACY=$(echo "$LAST_BLOCK" | grep -m 1 "Accuracy:" | awk '{print $2}' | sed 's/meters//')

# Handle optional fields with default values
SPEED=$(echo "$LAST_BLOCK" | grep -m 1 "Speed:" | awk '{print $2}' | sed 's/meters\/second//' || echo "10.000001")
HEADING=$(echo "$LAST_BLOCK" | grep -m 1 "Heading:" | awk '{print $2}' | sed 's/°//' || echo "100.000001")

# Extract and format the timestamp
TIMESTAMP=$(echo "$LAST_BLOCK" | grep -m 1 "Timestamp:" | sed -n 's/Timestamp: *\(.*\) (\(.*\))/\1/p' | xargs -I{} date -d "{}" +"%Y-%m-%d %H:%M:%S")

# Verify that timestamp is present
if [ -z "$TIMESTAMP" ]; then
    echo "Error: Missing timestamp."
    kill $AGENT_PID
    wait $AGENT_PID 2>/dev/null
    exit 1
fi

# Handle empty fields for latitude, longitude, and accuracy
if [ -z "$LATITUDE" ] || [ -z "$LONGITUDE" ] || [ -z "$ACCURACY" ]; then
    echo "Error: Missing required location data."
    kill $AGENT_PID
    wait $AGENT_PID 2>/dev/null
    exit 1
fi

# Check if accuracy is less than or equal to 100 meters
if [ $(echo "$ACCURACY <= 10000000000" | bc) -eq 1 ]; then
    # Create a JSON payload
    JSON_PAYLOAD=$(cat <<EOF
{
  "latitude": "$LATITUDE",
  "longitude": "$LONGITUDE",
  "accuracy": "$ACCURACY",
  "speed": "$SPEED",
  "heading": "$HEADING",
  "timestamp": "$TIMESTAMP"
}
EOF
    )

    echo "$JSON_PAYLOAD"

    # Send the data to the Flask server using a POST request
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$SERVER_URL" \
        -H "Content-Type: application/json" \
        -d "$JSON_PAYLOAD")

    # Check if the request was successful
    if [ "$RESPONSE" -eq 200 ]; then
        echo "Location data sent successfully!"
    else
        echo "Failed to send location data. HTTP status code: $RESPONSE"
    fi
else
    echo "Accuracy is higher than 100 meters; data not sent."
fi

# Stop the geoclue agent
kill $AGENT_PID

# Ensure the agent process is terminated
wait $AGENT_PID 2>/dev/null

