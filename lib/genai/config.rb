require "net/http"
require "json"

module Genai
  class Config
    attr_accessor :api_key, :base_url, :timeout, :max_retries
    
    def initialize(api_key: nil, base_url: nil, timeout: 60, max_retries: 3)
      @api_key = api_key || ENV["GEMINI_API_KEY"]
      @base_url = base_url || "https://generativelanguage.googleapis.com"
      @timeout = timeout
      @max_retries = max_retries
      
      validate_config!
    end
    
    def validate_config!
      raise Error, "API key is required. Set GEMINI_API_KEY environment variable or pass api_key parameter." if @api_key.nil? || @api_key.empty?
    end
    
    def api_url(endpoint)
      "#{@base_url}/v1beta/#{endpoint}"
    end
    
    def headers
      {
        "Content-Type" => "application/json",
        "x-goog-api-key" => @api_key
      }
    end
  end
end 