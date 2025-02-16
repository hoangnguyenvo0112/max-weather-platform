# app/weather.py

import openmeteo_requests
import requests_cache
import pandas as pd
from retry_requests import retry

def fetch_weather():
    """
    Fetch weather data from the Open-Meteo API for Tokyo (latitude: 35.6854, longitude: 139.7531).
    This function sets up caching and retry mechanisms, processes the returned JSON data,
    and returns a dictionary containing the weather information.
    """
    # Set up a cached session (cache expires after 3600 seconds - 1 hour)
    cache_session = requests_cache.CachedSession('.cache', expire_after=3600)

    # Apply retry logic (5 retries, backoff factor = 0.2)
    retry_session = retry(cache_session, retries=5, backoff_factor=0.2)

    # Initialize the Open-Meteo API client with the configured session
    openmeteo = openmeteo_requests.Client(session=retry_session)

    # Define the API endpoint and parameters (only fetching hourly temperature)
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": 35.6854,
        "longitude": 139.7531,
        "hourly": "temperature_2m"
    }

    # Make the API call; openmeteo.weather_api returns a list of responses
    responses = openmeteo.weather_api(url, params=params)

    # Process the first (and only) response
    response = responses[0]

    # Process hourly data
    hourly = response.Hourly()
    hourly_temperature_2m = hourly.Variables(0).ValuesAsNumpy()

    # Create a date range based on the API's time information
    hourly_data = {
        "date": pd.date_range(
            start=pd.to_datetime(hourly.Time(), unit="s", utc=True),
            end=pd.to_datetime(hourly.TimeEnd(), unit="s", utc=True),
            freq=pd.Timedelta(seconds=hourly.Interval()),
            inclusive="left"
        )
    }
    hourly_data["temperature_2m"] = hourly_temperature_2m

    # Combine the dates and temperatures into a DataFrame
    hourly_dataframe = pd.DataFrame(data=hourly_data)

    # Convert the DataFrame into a list of dictionaries with ISO-formatted dates for JSON serialization
    hourly_records = []
    for record in hourly_dataframe.itertuples(index=False):
        hourly_records.append({
            "date": record.date.isoformat(),
            "temperature_2m": record.temperature_2m
        })

    # Build the final weather information dictionary
    weather_info = {
        "coordinates": {
            "latitude": response.Latitude(),
            "longitude": response.Longitude()
        },
        "elevation": response.Elevation(),
        "timezone": response.Timezone(),
        "timezone_abbreviation": response.TimezoneAbbreviation(),
        "utc_offset_seconds": response.UtcOffsetSeconds(),
        "hourly": hourly_records
    }

    return weather_info
