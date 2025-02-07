require "test_helper"

module Llm
  module Providers
    class MockTest < ActiveSupport::TestCase
      setup do
        @provider = Llm::Providers::Mock.new({})
      end

      test "generates background for background request" do
        response = @provider.chat(messages: [{ 'role' => 'user', 'content' => 'background' }])
        
        assert_kind_of Hash, response
        assert response.key?('background'), "Response should include 'background' key"
        assert response.key?('personality_traits'), "Response should include 'personality_traits' key"
        assert_kind_of Array, response['personality_traits']
        assert_not_empty response['background'], "Background should not be empty"
        assert_not_empty response['personality_traits'], "Personality traits should not be empty"
      end

      test "returns empty hash for invalid message format" do
        response = @provider.chat(messages: [{ 'role' => 'invalid', 'content' => 'test' }])
        assert_equal({}, response)
      end

      test "test_connection returns true" do
        assert @provider.test_connection
      end
    end
  end
end 
