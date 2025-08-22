class LocationsController < ApplicationController
  class WeatherApiError < StandardError; end

  before_action do
    if (@instrument = params[:instrument].present?)
      request.variant = :instrumented
    end
  end

  def index
    @locations = Location.all
    @location = Location.new
  end

  def show
    @location = Location.find(params[:id])

    # GET request to geocoding-api.open-meteo.com
    geocode = geocode_location(@location.name)

    # GET request to api.weather.gov
    metadata = maybe_instrument(title: "Fetch weather metadata") {
      fetch_weather_metadata(geocode[:lat], geocode[:lon])
    }

    # Active Record UPDATE
    update_location_data(geocode, metadata)

    # GET request to api.weather.gov
    @weather_data = maybe_instrument(title: "Fetch weather forecast") {
       fetch_weather_forecast(metadata["properties"]["forecast"])
    }
  rescue WeatherApiError => e
    render text: e.message, status: 500
  end

  def create
    redirect_to Location.create!(location_params)
  end

  private

  def maybe_instrument(*)
    if @instrument
      Skylight.instrument(*) { yield }
    else
      yield
    end
  end
  
  def location_params
    params.require(:location).permit(:name)
  end

  def geocode_location(name)
    response = Faraday.get("https://geocoding-api.open-meteo.com/v1/search", { name: name })

    raise WeatherApiError, "Failed to geocode location" unless response.success?

    data = JSON.parse(response.body)
    results = data["results"]

    raise WeatherApiError, "Location not found in geocoding" unless results&.any?

    result = results.first
    { lat: result["latitude"], lon: result["longitude"] }
  end

  def fetch_weather_metadata(lat, lon)
    # Round coordinates to 4 decimal places as required by weather.gov API
    rounded_lat = lat.round(4)
    rounded_lon = lon.round(4)
    response = Faraday.get("https://api.weather.gov/points/#{rounded_lat},#{rounded_lon}")

    raise WeatherApiError, "Failed to fetch weather metadata" unless response.success?

    JSON.parse(response.body)
  end

  def update_location_data(geocode, metadata)
    # A bit contrived, but use update_columns to force the UPDATE to happen
    @location.update_columns(
      lat: geocode[:lat],
      lon: geocode[:lon],
      forecast_office: metadata.dig("properties", "gridId"),
      grid_x: metadata.dig("properties", "gridX"),
      grid_y: metadata.dig("properties", "gridY"),
    )
  end

  def fetch_weather_forecast(forecast_url)
    response = Faraday.get(forecast_url)

    raise WeatherApiError, "Failed to fetch weather data" unless response.success?

    JSON.parse(response.body)
  end
end