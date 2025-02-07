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
                    generate_background
                  when /equipment/i
                    suggest_equipment
                  when /spells/i
                    suggest_spells
                  else
                    { error: 'Unknown request type' }
                  end

        log_response(:chat, response)
        response
      end

      def test_connection
        true
      end

      private

      def generate_background
        {
          'background' => "In the bustling port city of Silverkeep, where the salt-laden winds carry tales of distant lands, Thalia Stormwind first discovered her love for music and adventure. Born to a human merchant father and an elven mother who was a celebrated performer in the local theater, Thalia's early years were steeped in the rich tapestry of two worlds.\n\nFrom her father, she learned the art of negotiation and the value of a well-told story, skills that would serve her well in her future endeavors. Her mother, meanwhile, nurtured her natural talent for music, teaching her the ancient songs of the elves and the power that music holds over hearts and minds. It was during one of her mother's performances that Thalia first experienced the magical nature of bardic music, watching in wonder as her mother's song literally brought tears of joy to the audience's eyes.\n\nThe defining moment in Thalia's life came during a devastating fire at the theater where her mother performed. As panic spread through the crowd, young Thalia found herself instinctively playing her mother's enchanted flute, her music calming the chaos and guiding people to safety. This event awakened something within her – a realization that her music could be more than just entertainment; it could be a force for good in the world.\n\nNow, Thalia travels the realm, collecting stories and songs, and using her talents to help those in need. Her chaotic good nature often leads her to bend rules she finds unjust, but always in service of what she believes is right. She's particularly drawn to situations where she can use her abilities to protect the innocent and preserve the artistic heritage of various cultures she encounters.",
          'personality_traits' => [
            'Charismatic performer who uses humor to diffuse tension',
            'Fiercely protective of artistic freedom and expression',
            'Curious collector of tales and musical traditions',
            'Impulsive when it comes to helping others in need'
          ]
        }
      end

      def suggest_equipment
        {
          'weapons' => ['Rapier', 'Hand Crossbow'],
          'armor' => ['Studded Leather Armor'],
          'adventuring_gear' => ['Backpack', 'Bedroll', 'Flute', 'Waterskin']
        }
      end

      def suggest_spells
        {
          'cantrips' => ['Vicious Mockery', 'Minor Illusion'],
          'level_1_spells' => ['Healing Word', 'Sleep']
        }
      end

      def log_request(method, **params)
        Rails.logger.info "[Mock LLM] Request: #{method} with params: #{params.inspect}"
      end

      def log_response(method, response)
        Rails.logger.info "[Mock LLM] Response: #{method} returned: #{response.inspect}"
      end

      def load_json(filename)
        path = if Rails.env.test?
                Rails.root.join('test', 'fixtures', 'files', filename)
              else
                Rails.root.join('mock', 'responses', filename)
              end
        
        unless File.exist?(path)
          Rails.logger.error "[Llm::Providers::Mock] Mock data file not found: #{path}"
          return {}
        end

        JSON.parse(File.read(path))
      rescue JSON::ParserError, Errno::ENOENT => e
        log_error(:load_json, e)
        {}
      end
    end
  end
end 