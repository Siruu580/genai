#!/usr/bin/env ruby

require_relative 'lib/genai'
require 'base64'

API_KEY = ""

begin
  client = Genai.new(api_key: API_KEY)

  puts "\n=== Basic Text Generation ==="
  response = client.generate_content(
    model: "gemini-2.0-flash",
    contents: [
      "당신은 한국어로만 응답하는 AI 어시스턴트입니다. 모든 답변은 한국어로만 해주세요.",
      "0.1 + 0.2 == 0.3이 True인지 False인지 설명해줘."
    ]
  )
  puts "#{response}"

  puts "\n=== Grounding Example ==="
  response = client.generate_content(
    model: "gemini-2.0-flash",
    contents: [
      "당신은 한국어로만 응답하는 AI 어시스턴트입니다. 모든 답변은 한국어로만 해주세요.",
      "겨울나라의 러블리즈 5는 안나옴?"
    ],
    grounding: true
  )
  puts "#{response}"

  puts "\n=== Image URL Example ==="
  image_url = "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png"
  response = client.generate_content(
    model: "gemini-2.0-flash",
    contents: [
      "당신은 한국어로만 응답하는 AI 어시스턴트입니다. 모든 답변은 한국어로만 해주세요.",
      "이 이미지를 한국어로 분석해줘:",
      image_url
    ]
  )
  puts "#{response}"

rescue => e
  puts "Error: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
end 