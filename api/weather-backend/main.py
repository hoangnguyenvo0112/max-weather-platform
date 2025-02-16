from flask import Flask, jsonify
from app.weather import fetch_weather

app = Flask(__name__)

# Define the application version
APP_VERSION = "1.0.0"

@app.route('/version', methods=['GET'])
def get_version():
    """Endpoint to check the application version."""
    return jsonify({"version": APP_VERSION})

@app.route('/weather', methods=['GET'])
def get_weather():
    """Endpoint to fetch weather information."""
    try:
        weather_data = fetch_weather()
        return jsonify(weather_data)
    except Exception as e:
        # Return an error message if something goes wrong during weather data fetching
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Run the application on host 0.0.0.0 and port 80 to accept external requests
    app.run(host='0.0.0.0', port=80, debug=True)
