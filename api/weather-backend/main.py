# app/main.py

from fastapi import FastAPI
from app.weather import fetch_weather

# Create a FastAPI application instance
app = FastAPI(
    title="Weather Backend API",
    description="A backend service that provides weather information using the Open-Meteo API.",
    version="1.0"
)

# Define an API endpoint to fetch weather data
@app.get("/weather", summary="Get weather forecast")
async def get_weather():
    """
    GET /weather

    Returns the weather forecast for the configured location.
    """
    weather_info = fetch_weather()
    return weather_info
