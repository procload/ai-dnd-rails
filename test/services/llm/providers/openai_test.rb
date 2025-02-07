# frozen_string_literal: true

require 'test_helper'

module Llm
  module Providers
    class OpenaiTest < ActiveSupport::TestCase
      # Use shorter windows for testing
      TEST_RATE_LIMIT_REQUESTS = 3
      TEST_RATE_LIMIT_WINDOW = 0.1 # 100ms

      def setup
        @config = {
          api_key: 'test-key',
          model: 'gpt-4-turbo-preview',
          max_tokens: 1024,
          temperature: 0.7
        }
        @provider = Llm::Providers::Openai.new(@config)
        
        # Override rate limiter for testing
        @provider.instance_variable_set(
          :@rate_limiter,
          Openai::RateLimiter.new(TEST_RATE_LIMIT_REQUESTS, TEST_RATE_LIMIT_WINDOW)
        )

        # Set up default request stub
        stub_openai_request(body: successful_response_body)
      end

      test 'initializes with valid configuration' do
        assert_kind_of Llm::Providers::Openai, @provider
      end

      test 'raises error with missing api_key' do
        config = @config.dup
        config.delete(:api_key)

        assert_raises Llm::Service::ConfigurationError do
          Llm::Providers::Openai.new(config)
        end
      end

      test 'raises error with missing model' do
        config = @config.dup
        config.delete(:model)

        assert_raises Llm::Service::ConfigurationError do
          Llm::Providers::Openai.new(config)
        end
      end

      test 'chat returns structured background response' do
        messages = [{ 'role' => 'user', 'content' => 'Generate a background for a D&D character' }]
        
        stub_openai_request(body: background_response_body)

        response = @provider.chat(messages: messages)
        assert_kind_of Hash, response
        assert response.key?('background')
        assert response.key?('personality_traits')
        assert_kind_of Array, response['personality_traits']
      end

      test 'chat returns structured equipment response' do
        messages = [{ 'role' => 'user', 'content' => 'Suggest equipment for my character' }]
        
        stub_openai_request(body: equipment_response_body)

        response = @provider.chat(messages: messages)
        assert_kind_of Hash, response
        assert response.key?('weapons')
        assert response.key?('armor')
        assert response.key?('adventuring_gear')
        assert_kind_of Array, response['weapons']
        assert_kind_of Array, response['armor']
        assert_kind_of Array, response['adventuring_gear']
      end

      test 'chat returns structured spells response' do
        messages = [{ 'role' => 'user', 'content' => 'Suggest spells for my character' }]
        
        stub_openai_request(body: spells_response_body)

        response = @provider.chat(messages: messages)
        assert_kind_of Hash, response
        assert response.key?('cantrips')
        assert response.key?('level_1_spells')
        assert_kind_of Array, response['cantrips']
        assert_kind_of Array, response['level_1_spells']
      end

      test 'chat raises error when no structured response received' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        
        stub_openai_request(body: { choices: [] }.to_json)

        assert_raises Llm::Service::ProviderError do
          @provider.chat(messages: messages)
        end
      end

      test 'chat handles unauthorized errors' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .to_return(status: 401)

        assert_raises Llm::Service::ProviderError do
          @provider.chat(messages: messages)
        end
      end

      test 'chat handles rate limit errors' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .to_return(status: 429)

        assert_raises Llm::Service::ProviderError do
          @provider.chat(messages: messages)
        end
      end

      test 'test_connection returns true for successful connection' do
        stub_openai_request(body: background_response_body)
        assert @provider.test_connection
      end

      test 'test_connection returns false for failed connection' do
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .to_return(status: 401)

        refute @provider.test_connection
      end

      test 'retries on rate limit error' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        
        # First attempt fails with rate limit, second succeeds
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => 'Bearer test-key'
            }
          )
          .to_return(
            { status: 429, headers: { 'retry-after' => '1' } },
            { status: 200, body: successful_response_body }
          )

        response = @provider.chat(messages: messages)
        assert_kind_of Hash, response
      end

      test 'retries on timeout' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        
        # First attempt times out, second succeeds
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => 'Bearer test-key'
            }
          )
          .to_timeout
          .then
          .to_return(status: 200, body: successful_response_body)

        response = @provider.chat(messages: messages)
        assert_kind_of Hash, response
      end

      test 'fails after max retries' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        
        # All attempts fail with rate limit
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => 'Bearer test-key'
            }
          )
          .to_return(status: 429).times(Llm::Providers::Openai::MAX_RETRIES + 1)

        assert_raises Llm::Service::ProviderError do
          @provider.chat(messages: messages)
        end
      end

      test 'rate limiter enforces request limits' do
        messages = [{ 'role' => 'user', 'content' => 'test' }]
        start_time = Time.now
        
        # Stub successful responses
        stub_openai_request(body: successful_response_body)

        # Make requests up to the limit
        (TEST_RATE_LIMIT_REQUESTS + 1).times do
          @provider.chat(messages: messages)
        end

        # Verify that the total time taken is at least the rate limit window
        assert_operator Time.now - start_time, :>=, TEST_RATE_LIMIT_WINDOW
      end

      private

      def background_response_body
        {
          choices: [
            {
              message: {
                role: 'assistant',
                content: JSON.generate({
                  background: 'A mysterious adventurer...',
                  personality_traits: ['Brave', 'Curious']
                })
              }
            }
          ]
        }.to_json
      end

      def equipment_response_body
        {
          choices: [
            {
              message: {
                role: 'assistant',
                content: JSON.generate({
                  weapons: ['Longsword', 'Shortbow'],
                  armor: ['Chain mail'],
                  adventuring_gear: ['Backpack', 'Rope']
                })
              }
            }
          ]
        }.to_json
      end

      def spells_response_body
        {
          choices: [
            {
              message: {
                role: 'assistant',
                content: JSON.generate({
                  cantrips: ['Fire Bolt', 'Mage Hand'],
                  level_1_spells: ['Magic Missile', 'Shield']
                })
              }
            }
          ]
        }.to_json
      end

      def successful_response_body
        background_response_body
      end

      def stub_openai_request(status: 200, body: successful_response_body, headers: {})
        stub_request(:post, Llm::Providers::Openai::OPENAI_API_URL)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => 'Bearer test-key'
            }
          )
          .to_return(
            status: status,
            body: body,
            headers: { 'Content-Type' => 'application/json' }.merge(headers)
          )
      end
    end
  end
end 