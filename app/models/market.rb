# Ticketmaster market data and the pricing engine. Prices inside the engine
# are buyer all-in per ticket (fees in, tax out) unless a name says "list".
module Market
  ENGINE_VERSION = "1".freeze

  # Where Kate's research starts: the Thunder's home games on Ticketmaster.
  TICKETMASTER_START_URL = "https://www.ticketmaster.com/oklahoma-city-thunder-tickets/artist/1250512?home_away=home".freeze
end
