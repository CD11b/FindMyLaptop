import os
import psycopg2
from flask import Flask, request, jsonify, render_template
import logging
import sys
from dotenv import load_dotenv
from werkzeug.exceptions import BadRequest

# Load environment variables from .env file
load_dotenv()

app = Flask(__name__)

# Configure logging to output to stdout
logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(asctime)s %(message)s')

# PostgreSQL connection settings (using environment variables)
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'db'),
    'dbname': os.getenv('DB_NAME', 'your_db'),
    'user': os.getenv('DB_USER', 'your_user'),
    'password': os.getenv('DB_PASSWORD', 'your_password')
}

# Initialize the database (create table if it doesn't exist)
def init_db():
    with psycopg2.connect(**DB_CONFIG) as conn:
        with conn.cursor() as cursor:
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS location (
                    id SERIAL PRIMARY KEY,
                    latitude FLOAT,
                    longitude FLOAT,
                    accuracy FLOAT,
                    speed FLOAT,
                    heading FLOAT,
                    timestamp TIMESTAMP
                )
            ''')
            conn.commit()

# Initialize the database at startup
init_db()

def validate_location_data(data):
    required_fields = ['latitude', 'longitude', 'accuracy', 'speed', 'heading', 'timestamp']
    if not all(field in data for field in required_fields):
        raise BadRequest("Missing data")

    latitude = float(data['latitude'])
    longitude = float(data['longitude'])
    if not (-90 <= latitude <= 90):
        raise BadRequest("Latitude must be between -90 and 90")
    if not (-180 <= longitude <= 180):
        raise BadRequest("Longitude must be between -180 and 180")
    
    return latitude, longitude, float(data['accuracy']), float(data['speed']), float(data['heading']), data['timestamp']

@app.route('/location', methods=['POST'])
def receive_location():
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400

    try:
        latitude, longitude, accuracy, speed, heading, timestamp = validate_location_data(data)
        
        logging.info(f"Received location: Latitude = {latitude}, Longitude = {longitude}, Accuracy = {accuracy}m, Speed = {speed}m/s, Heading = {heading}°, Timestamp = {timestamp}")

        with psycopg2.connect(**DB_CONFIG) as conn:
            with conn.cursor() as cursor:
                cursor.execute('''
                    INSERT INTO location (latitude, longitude, accuracy, speed, heading, timestamp)
                    VALUES (%s, %s, %s, %s, %s, %s)
                ''', (latitude, longitude, accuracy, speed, heading, timestamp))
                conn.commit()

        return jsonify({"status": "success"}), 200

    except BadRequest as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        logging.error(f"Error: {e}")
        return jsonify({"error": "An unexpected error occurred"}), 500

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/location-data', methods=['GET'])
def location_data():
    try:
        with psycopg2.connect(**DB_CONFIG) as conn:
            with conn.cursor() as cursor:
                cursor.execute('SELECT latitude, longitude, accuracy, speed, heading, timestamp FROM location')
                data = cursor.fetchall()

        result = [
            {
                "latitude": row[0],
                "longitude": row[1],
                "accuracy": row[2],
                "speed": row[3],
                "heading": row[4],
                "timestamp": row[5].strftime("%Y-%m-%d %H:%M:%S")
            }
            for row in data
        ]

        return jsonify(result)

    except Exception as e:
        logging.error(f"Error retrieving location data: {e}")
        return jsonify({"error": "An unexpected error occurred"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

