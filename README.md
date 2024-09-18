1. Clone the repository onto your server
2. Adjust values in .env and docker-compose.yml, if desired. You should probably add your network/proxy configuration now.
3. `docker compose build`
4. `docker compose up -d`
6. Install geoclue on client computer
7. Download the ClientPOST.sh script and `chmod +x` it. You may need to switch the wifi provier to beacondb in `/etc/geoclue/geoclue.conf` now that Mozilla Location Services has closed.
8. Execute the script (preferably, with a cron job) to send location data to server
