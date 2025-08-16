require_relative "genai/config"
require_relative "genai/model"
require_relative "genai/chat"
require_relative "genai/version"

module Genai
  class Error < StandardError; end
  
  class Client
    attr_reader :config
    
    def initialize(api_key: nil, **options)
      @config = Config.new(api_key: api_key, **options)
    end
    
    def model(model_id)
      Model.new(self, model_id)
    end
    
    def chats
      Chats.new(self)
    end
    
    def generate_content(model:, contents:, **options)
      self.model(model).generate_content(contents: contents, **options)
    end
  end
  
  def self.new(**options)
    Client.new(**options)
  end
end 