require "test_helper"

module Llm
  class ServiceTest < ActiveSupport::TestCase
    setup do
      # Ensure we're using the mock provider for tests
      @original_provider = Rails.configuration.llm.provider
      Rails.configuration.llm.provider = :mock
    end

    teardown do
      # Restore original provider
      Rails.configuration.llm.provider = @original_provider
    end

    test "initializes with configured provider" do
      service = Llm::Service.new
      assert_kind_of Llm::Providers::Base, service.provider
      assert_kind_of Llm::Providers::Mock, service.provider
    end

    test "chat delegates to provider and returns valid response" do
      service = Llm::Service.new
      messages = [{ 'role' => 'user', 'content' => 'background' }]
      
      response = service.chat(messages: messages)
      assert_kind_of Hash, response, "Response should be a Hash"
      assert response.key?('background'), "Response should include 'background' key"
      assert response.key?('personality_traits'), "Response should include 'personality_traits' key"
      assert_kind_of Array, response['personality_traits'], "Personality traits should be an array"
    end
  end
end 
