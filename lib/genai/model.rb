require "net/http"
require "json"
require "uri"
require 'base64'
require 'cgi'

module Genai
  class Model
    attr_reader :client, :model_id
    
    def initialize(client, model_id)
      @client = client
      @model_id = model_id
    end
    
    def generate_content(contents:, tools: nil, config: nil, grounding: nil, **options)
      tools = Array(tools).dup if tools
      if grounding
        if grounding.is_a?(Hash) && grounding[:dynamic_threshold]
          tools ||= []
          tools << self.class.grounding_with_dynamic_threshold(grounding[:dynamic_threshold])
        else
          tools ||= []
          tools << self.class.grounding_tool
        end
      end
      
      contents_with_urls = extract_and_add_urls(contents)
      request_body = build_request_body(contents: contents_with_urls, tools: tools, config: config, **options)
      response = make_request(request_body)
      parse_response(response)
    end

    def self.grounding_tool
      { google_search: {} }
    end

    def self.grounding_with_dynamic_threshold(threshold)
      {
        google_search_retrieval: {
          dynamic_retrieval_config: {
            mode: "MODE_DYNAMIC",
            dynamic_threshold: threshold
          }
        }
      }
    end
    
    private
    
    def extract_and_add_urls(contents)
      if contents.is_a?(String)
        urls = extract_urls_from_text(contents)
        if urls.any?
          return [
            { role: "user", parts: [{ text: contents }] },
            *urls.map { |url| { role: "user", parts: [{ text: url }] } }
          ]
        end
      end
      contents
    end
    
    def extract_urls_from_text(text)
      url_pattern = /https?:\/\/[^\s]+/
      text.scan(url_pattern)
    end
    
    def build_request_body(contents:, tools: nil, config: nil, **options)
      body = {
        contents: normalize_contents(contents)
      }
      
      body[:tools] = normalize_tools(tools) if tools
      body[:generationConfig] = normalize_config(config) if config
      
      options.each { |key, value| body[key] = value }
      
      body
    end
    
    def normalize_contents(contents)
      if contents.is_a?(String)
        if is_image_url?(contents) || is_base64_image?(contents)
          [{ role: "user", parts: [{ inline_data: { mime_type: detect_mime_type(contents), data: extract_image_data(contents) } }] }]
        else
          [{ role: "user", parts: [{ text: contents }] }]
        end
      elsif contents.is_a?(Array)
        contents.map do |content|
          if content.is_a?(String)
            if is_image_url?(content) || is_base64_image?(content)
              { role: "user", parts: [{ inline_data: { mime_type: detect_mime_type(content), data: extract_image_data(content) } }] }
            else
              { role: "user", parts: [{ text: content }] }
            end
          elsif content.is_a?(Hash)
            content[:role] ||= "user"
            content
          else
            raise Error, "Invalid content format: #{content.class}"
          end
        end
              elsif contents.is_a?(Hash)
          contents[:role] ||= "user"
          [contents]
        else
          raise Error, "Invalid contents format: #{contents.class}"
        end
    end

    def is_image_url?(text)
      image_extensions = %w[.jpg .jpeg .png .gif .webp .bmp .tiff]
      text.match?(/^https?:\/\/.+/i) && image_extensions.any? { |ext| text.downcase.include?(ext) }
    end

    def is_base64_image?(text)
      text.match?(/^data:image\/[a-zA-Z]+;base64,/)
    end

    def detect_mime_type(content)
      if is_image_url?(content)
        case content.downcase
        when /\.(jpg|jpeg)$/
          "image/jpeg"
        when /\.png$/
          "image/png"
        when /\.gif$/
          "image/gif"
        when /\.webp$/
          "image/webp"
        when /\.bmp$/
          "image/bmp"
        when /\.tiff$/
          "image/tiff"
        else
          "image/jpeg"
        end
      elsif is_base64_image?(content)
        match = content.match(/^data:image\/([a-zA-Z]+);base64,/)
        if match
          "image/#{match[1]}"
        else
          "image/jpeg"
        end
      else
        "text/plain"
      end
    end

    def extract_image_data(content)
      if is_image_url?(content)
        download_and_encode_image(content)
      elsif is_base64_image?(content)
        content.match(/^data:image\/[a-zA-Z]+;base64,(.+)$/)[1]
      else
        content
      end
    end

    def download_and_encode_image(url)
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 10
        
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          Base64.strict_encode64(response.body)
        else
          raise Error, "Failed to download image: #{response.code}"
        end
      rescue => e
        raise Error, "Error downloading image: #{e.message}"
      end
    end
    
    def normalize_tools(tools)
      return [] if tools.nil?
      
      if tools.is_a?(Array)
        tools.map { |tool| normalize_tool(tool) }
      else
        [normalize_tool(tools)]
      end
    end
    
    def normalize_tool(tool)
      case tool
      when Hash
        tool
      when :url_context, "url_context"
        { url_context: {} }
      when :google_search, "google_search"
        { google_search: {} }
      when :google_search_retrieval, "google_search_retrieval"
        { google_search_retrieval: {} }
      else
        raise Error, "Unknown tool: #{tool}"
      end
    end
    
    def normalize_config(config)
      return {} if config.nil?
      
      if config.is_a?(Hash)
        config
      else
        raise Error, "Config must be a Hash"
      end
    end
    
    def make_request(request_body)
      uri = URI(client.config.api_url("models/#{model_id}:generateContent"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = client.config.timeout
      http.read_timeout = client.config.timeout
      
      request = Net::HTTP::Post.new(uri)
      client.config.headers.each { |key, value| request[key] = value }
      request.body = request_body.to_json
      
      response = http.request(request)
      
      case response
      when Net::HTTPSuccess
        response
      when Net::HTTPClientError
        raise Error, "Client error: #{response.code} - #{response.body}"
      when Net::HTTPServerError
        raise Error, "Server error: #{response.code} - #{response.body}"
      else
        raise Error, "Unexpected response: #{response.code} - #{response.body}"
      end
    end
    
    def parse_response(response)
      data = JSON.parse(response.body)
      
      candidates = data["candidates"] || []
      return "" if candidates.empty?
      
      content = candidates.first["content"]
      parts = content["parts"] || []
      
      text_parts = parts.map { |part| part["text"] }.compact
      text = text_parts.join
      
      if candidates.first["groundingMetadata"]
        grounding_info = candidates.first["groundingMetadata"]
        if grounding_info["groundingChunks"]
          text += "\n\n참고한 URL:\n"
          grounding_info["groundingChunks"].each_with_index do |chunk, index|
            if chunk["web"]
              original_url = extract_original_url(chunk["web"]["uri"])
              decoded_url = original_url.gsub(/\\u([0-9a-fA-F]{4})/) { |m| [$1.to_i(16)].pack('U') }
              decoded_url = CGI.unescape(decoded_url)
              encoded_url = decoded_url.gsub(' ', '%20')
              text += "#{index + 1}. #{encoded_url}\n"
            end
          end
        end
      end
      
      text
    end
    
    def extract_original_url(redirect_url)
      return redirect_url unless redirect_url.include?("vertexaisearch.cloud.google.com")
      
      final_url = follow_redirects(redirect_url)
      return final_url if final_url && final_url != redirect_url
      
      begin
        uri = URI(redirect_url)
        
        path_parts = uri.path.split("/")
        if path_parts.include?("grounding-api-redirect")
          encoded_url = path_parts.last
          
          decoded_url = try_decode_url(encoded_url)
          return decoded_url if decoded_url && decoded_url.start_with?("http")
        end
        
        if uri.query
          params = URI.decode_www_form(uri.query)
          original_url = params.find { |k, v| k == "url" || k == "original_url" || k == "target" }&.last
          return original_url if original_url && original_url.start_with?("http")
        end
        
        if uri.query && uri.query.include?("http")
          url_match = uri.query.match(/https?:\/\/[^\s&]+/)
          return url_match[0] if url_match
        end
        
        if ENV['DEBUG']
          puts "URL 파싱 실패 - 구조:"
          puts "  전체 URL: #{redirect_url}"
          puts "  경로: #{uri.path}"
          puts "  쿼리: #{uri.query}"
          puts "  인코딩된 부분: #{path_parts.last}" if path_parts.last
        end
        
      rescue => e
        puts "URL 파싱 오류: #{e.message}" if ENV['DEBUG']
      end
      
      redirect_url
    end
    
    def follow_redirects(url, max_redirects = 5)
      current_url = url
      redirect_count = 0
      
      while redirect_count < max_redirects
        begin
          uri = URI(current_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if uri.scheme == 'https'
          http.open_timeout = 10
          http.read_timeout = 10
          
          request = Net::HTTP::Get.new(uri)
          request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          
          response = http.request(request)
          
          case response
          when Net::HTTPRedirection
            redirect_count += 1
            location = response['location']
            if location
              if location.start_with?('/')
                current_url = "#{uri.scheme}://#{uri.host}#{location}"
              elsif location.start_with?('http')
                current_url = location
              else
                current_url = "#{uri.scheme}://#{uri.host}/#{location}"
              end
            else
              break
            end
          else
            return current_url
          end
        rescue => e
          puts "리다이렉트 추적 오류: #{e.message}" if ENV['DEBUG']
          return url
        end
      end
      
      current_url
    end
    
    def try_decode_url(encoded_url)
      begin
        require 'base64'
        decoded_bytes = Base64.urlsafe_decode64(encoded_url)
        decoded_url = decoded_bytes.force_encoding('UTF-8')
        return decoded_url if decoded_url.start_with?("http")
      rescue
      end
      
      begin
        decoded_bytes = Base64.decode64(encoded_url)
        decoded_url = decoded_bytes.force_encoding('UTF-8')
        return decoded_url if decoded_url.start_with?("http")
      rescue
      end
      
      begin
        decoded_url = URI.decode(encoded_url)
        return decoded_url if decoded_url.start_with?("http")
      rescue
      end
      
      begin
        padded_url = encoded_url + "=" * (4 - encoded_url.length % 4)
        decoded_bytes = Base64.decode64(padded_url)
        decoded_url = decoded_bytes.force_encoding('UTF-8')
        return decoded_url if decoded_url.start_with?("http")
      rescue
      end
      
      nil
    end
  end
end 