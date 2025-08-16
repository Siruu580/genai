module Genai
  module ChatValidator
    def self.validate_content(content)
      return false unless content[:parts] && !content[:parts].empty?
      content[:parts].each do |part|
        return false if part.empty?
        return false if part[:text] && part[:text].empty?
      end
      true
    end

    def self.validate_contents(contents)
      return false if contents.empty?
      contents.each do |content|
        return false unless validate_content(content)
      end
      true
    end

    def self.validate_response(response)
      return false unless response[:candidates] && !response[:candidates].empty?
      return false unless response[:candidates][0][:content]
      validate_content(response[:candidates][0][:content])
    end

    def self.extract_curated_history(comprehensive_history)
      return [] if comprehensive_history.empty?
      
      curated_history = []
      length = comprehensive_history.length
      i = 0
      
      while i < length
        unless ["user", "model"].include?(comprehensive_history[i][:role])
          raise ArgumentError, "Role must be user or model, but got #{comprehensive_history[i][:role]}"
        end

        if comprehensive_history[i][:role] == "user"
          current_input = comprehensive_history[i]
          curated_history << current_input
          i += 1
        else
          current_output = []
          is_valid = true
          
          while i < length && comprehensive_history[i][:role] == "model"
            current_output << comprehensive_history[i]
            if is_valid && !validate_content(comprehensive_history[i])
              is_valid = false
            end
            i += 1
          end
          
          if is_valid
            curated_history.concat(current_output)
          elsif !curated_history.empty?
            curated_history.pop
          end
        end
      end
      
      curated_history
    end
  end

  class BaseChat
    attr_reader :model, :config, :comprehensive_history, :curated_history

    def initialize(model:, config: nil, history: [])
      @model = model
      @config = config
      
      content_models = history.map do |content|
        content.is_a?(Hash) ? content : content
      end
      
      @comprehensive_history = content_models
      @curated_history = ChatValidator.extract_curated_history(content_models)
    end

    def record_history(user_input:, model_output:, automatic_function_calling_history: [], is_valid: true)
      input_contents = if !automatic_function_calling_history.empty?
        automatic_function_calling_history[@curated_history.length..-1] || [user_input]
      else
        [user_input]
      end
      
      output_contents = model_output.empty? ? [{ role: "model", parts: [] }] : model_output
      
      @comprehensive_history.concat(input_contents)
      @comprehensive_history.concat(output_contents)
      
      if is_valid
        @curated_history.concat(input_contents)
        @curated_history.concat(output_contents)
      end
    end

    def get_history(curated: false)
      curated ? @curated_history : @comprehensive_history
    end
  end

  class Chat < BaseChat
    def initialize(client:, model:, config: nil, history: [])
      @client = client
      super(model: model, config: config, history: history)
    end

    def send_message(message, config: nil)
      input_content = case message
      when String
        { role: "user", parts: [{ text: message }] }
      when Array
        { role: "user", parts: message }
      when Hash
        message
      else
        raise ArgumentError, "Message must be a String, Array, or Hash"
      end

      model_instance = @client.model(@model)
      response = model_instance.generate_content(
        contents: @curated_history + [input_content],
        config: config || @config
      )

      model_output = if response[:candidates] && !response[:candidates].empty? && response[:candidates][0][:content]
        [response[:candidates][0][:content]]
      else
        []
      end

      automatic_function_calling_history = response[:automatic_function_calling_history] || []

      record_history(
        user_input: input_content,
        model_output: model_output,
        automatic_function_calling_history: automatic_function_calling_history,
        is_valid: ChatValidator.validate_response(response)
      )

      response
    end

    def send_message_stream(message, config: nil)
      input_content = case message
      when String
        { role: "user", parts: [{ text: message }] }
      when Array
        { role: "user", parts: message }
      when Hash
        message
      else
        raise ArgumentError, "Message must be a String, Array, or Hash"
      end


      send_message(message, config: config)
    end
  end

  class Chats
    def initialize(client)
      @client = client
      @user_sessions = {}
    end

    def create(model:, config: nil, history: [])
      Chat.new(client: @client, model: model, config: config, history: history)
    end

    def get_user_session(user_id, model: "gemini-2.0-flash", config: nil)
      unless @user_sessions[user_id]
        @user_sessions[user_id] = create(
          model: model,
          config: config || {
            temperature: 0.7,
            max_output_tokens: 2048
          }
        )
      end
      
      @user_sessions[user_id]
    end

    def clear_user_session(user_id)
      @user_sessions.delete(user_id)
    end

    def clear_all_sessions
      @user_sessions.clear
    end

    def get_session_count
      @user_sessions.length
    end

    def get_active_users
      @user_sessions.keys
    end
  end
end
