
# Genai

An unofficial Ruby package for Google Gemini. Easily generate text and images, analyze web content, and integrate Google Search—all with a simple Ruby API.

## Installation

Add to your Gemfile:

```ruby
gem 'genai-rb'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install genai-rb
```

## Usage

### Setup

Get your Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey).

Set your API key:

```bash
export GEMINI_API_KEY="api_key"
```

Or pass it directly:

```ruby
require 'genai'
client = Genai.new(api_key: "api_key")
```

### Text Generation

```ruby
response = client.generate_content(contents: "Hello, how are you?")
puts response
```

### Use a Specific Model

```ruby
response = client.generate_content(model_id: "gemini-2.5-flash", contents: "Explain quantum computing.")
```

### URL Context

```ruby
response = client.generate_content(contents: "Summarize: https://example.com/article", tools: [:url_context])
```

### Google Search Integration

```ruby
response = client.generate_content(contents: "Latest AI news?", tools: [:google_search, :url_context])
```

### Advanced Configuration

```ruby
client = Genai.new(api_key: "api_key", timeout: 120, max_retries: 5)
response = client.model("gemini-2.0-flash").generate_content(
  contents: "Write a creative story about a robot learning to paint",
  config: { temperature: 0.8, max_output_tokens: 1000 }
)
```

### Model Instances

```ruby
model = client.model("gemini-2.5-flash")
response = model.generate_content(contents: "Explain the benefits of renewable energy")
```

## Supported Models

- All Gemini models

## Features

- Text and image generation
- URL context analysis
- Google Search integration
- Multiple model support
- Customizable generation config
- Robust error handling and retry logic
- Simple, intuitive Ruby API

## Contributing

Pull requests are always welcome.

## License

Open source under the [MIT License](https://opensource.org/licenses/MIT).