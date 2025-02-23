# frozen_string_literal: true

module Llm
  module Providers
    class Mock < Base
      def chat(messages:, system_prompt: nil)
        log_request(:chat, messages: messages, system_prompt: system_prompt)
        
        # Extract the last user message which contains our request
        last_message = messages.last
        return {} unless last_message['role'] == 'user'

        # Parse the request type from the message
        request = last_message['content']
        
        response = case request
                  when /background/i
                    load_mock_response('character_background.json')
                  when /traits/i
                    load_mock_response('character_traits.json')
                  when /equipment/i
                    suggest_equipment
                  when /spells/i
                    suggest_spells
                  when /personality_details/i
                    generate_personality_details
                  else
                    { error: 'Unknown request type' }
                  end

        log_response(:chat, response)
        response
      end

      def chat_with_schema(messages:, system_prompt: nil, schema:, provider_config: nil)
        log_request(:chat_with_schema, messages: messages, system_prompt: system_prompt, schema: schema)
        
        # Get base response from chat method
        response = chat(messages: messages, system_prompt: system_prompt)
        
        # Validate response against schema
        validate_response_against_schema!(response, schema)
        
        log_response(:chat_with_schema, response)
        response
      end

      def test_connection
        true
      end

      private

      def load_mock_response(filename)
        path = Rails.root.join('test', 'fixtures', 'files', 'mock_responses', filename)
        JSON.parse(File.read(path))
      rescue JSON::ParserError, Errno::ENOENT => e
        log_error(:load_mock_response, e)
        raise Llm::Service::ProviderError, "Failed to load mock response: #{e.message}"
      end

      def suggest_equipment
        {
          'weapons' => [
            { 'name' => 'Longsword', 'damage' => '1d8 slashing' },
            { 'name' => 'Shortbow', 'damage' => '1d6 piercing' }
          ],
          'armor' => [
            { 'name' => 'Chain Mail', 'ac' => 16 }
          ],
          'adventuring_gear' => [
            'Backpack',
            'Bedroll',
            'Rations (10 days)',
            'Waterskin'
          ]
        }
      end

      def suggest_spells
        {
          'cantrips' => [
            { 'name' => 'Fire Bolt', 'school' => 'Evocation' },
            { 'name' => 'Mage Hand', 'school' => 'Conjuration' },
            { 'name' => 'Light', 'school' => 'Evocation' }
          ],
          'level_1_spells' => [
            { 'name' => 'Magic Missile', 'school' => 'Evocation' },
            { 'name' => 'Shield', 'school' => 'Abjuration' },
            { 'name' => 'Mage Armor', 'school' => 'Abjuration' }
          ]
        }
      end

      def generate_personality_details
        {
          'ideals' => [
            { 'ideal' => 'Justice Above All', 'manifestation' => 'Will always stand up for the downtrodden, even at personal cost' },
            { 'ideal' => 'Knowledge is Power', 'manifestation' => 'Seeks to understand the deeper mysteries of the world' }
          ],
          'bonds' => [
            { 'bond' => "Mentor's Legacy", 'manifestation' => 'Carries the teachings and final mission of their departed master' },
            { 'bond' => 'Chosen Family', 'manifestation' => 'Has found a new family among their adventuring companions' }
          ],
          'flaws' => [
            { 'flaw' => 'Pride Before Reason', 'manifestation' => 'Often refuses help even when clearly needed' },
            { 'flaw' => 'Haunted by the Past', 'manifestation' => 'Recurring nightmares affect their judgment in similar situations' }
          ]
        }
      end
    end
  end
end 