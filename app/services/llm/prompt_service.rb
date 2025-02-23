# frozen_string_literal: true

module Llm
  # Service for managing and generating prompts for LLM providers
  class PromptService
    class Error < StandardError; end
    class TemplateNotFoundError < Error; end
    class ValidationError < Error; end
    class SchemaValidationError < ValidationError; end

    class << self
      def generate(request_type:, provider:, **context)
        new.generate(
          request_type: request_type,
          provider: provider,
          **context
        )
      end
    end

    def generate(request_type:, provider:, **context)
      template = load_template(request_type, provider)
      validate_template!(template)
      render_template(template, provider, context)
    end

    private

    def load_template(request_type, provider)
      Rails.cache.fetch(cache_key(request_type, provider)) do
        load_template_from_disk(request_type, provider)
      end
    rescue TemplateNotFoundError => e
      Rails.logger.warn "[PromptService] #{e.message}, falling back to default template"
      load_default_template(request_type)
    end

    def load_template_from_disk(request_type, provider)
      paths_to_try = template_paths(request_type, provider)
      template_path = paths_to_try.find { |path| File.exist?(path) }

      unless template_path
        paths_tried = paths_to_try.map { |p| p.relative_path_from(Rails.root) }.join(', ')
        raise TemplateNotFoundError, "No template found for #{request_type} (tried: #{paths_tried})"
      end

      YAML.load_file(template_path)
    end

    def template_paths(request_type, provider)
      [
        Rails.root.join('config', 'prompts', provider.to_s, "#{request_type}.yml"),
        Rails.root.join('config', 'prompts', 'default', "#{request_type}.yml")
      ]
    end

    def load_default_template(request_type)
      case request_type
      when 'character_background'
        default_background_template
      when 'suggest_equipment'
        default_equipment_template
      when 'suggest_spells'
        default_spells_template
      else
        raise TemplateNotFoundError, "No default template for #{request_type}"
      end
    end

    def default_background_template
      {
        'system_prompt' => 'You are a D&D character background generator. Create a unique and compelling background story.',
        'user_prompt' => 'Generate a background for a {{class}} named {{name}}.',
        'schema' => {
          'type' => 'object',
          'required' => ['background', 'personality_traits'],
          'properties' => {
            'background' => {
              'type' => 'string',
              'description' => 'A detailed background story for the character'
            },
            'personality_traits' => {
              'type' => 'array',
              'description' => 'List of personality traits that define the character',
              'items' => { 'type' => 'string' },
              'minItems' => 2,
              'maxItems' => 4
            }
          }
        }
      }
    end

    def default_equipment_template
      {
        'system_prompt' => 'You are a D&D equipment advisor. Suggest appropriate equipment for characters.',
        'user_prompt' => 'Suggest equipment for a level {{level}} {{class}}.',
        'schema' => {
          'type' => 'object',
          'required' => ['weapons', 'armor', 'adventuring_gear'],
          'properties' => {
            'weapons' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => ['name', 'damage'],
                'properties' => {
                  'name' => { 'type' => 'string' },
                  'damage' => { 'type' => 'string' }
                }
              },
              'maxItems' => 4
            },
            'armor' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => ['name', 'ac'],
                'properties' => {
                  'name' => { 'type' => 'string' },
                  'ac' => { 'type' => 'integer' }
                }
              },
              'maxItems' => 2
            },
            'adventuring_gear' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => ['name'],
                'properties' => {
                  'name' => { 'type' => 'string' }
                }
              },
              'maxItems' => 8
            }
          }
        }
      }
    end

    def default_spells_template
      {
        'system_prompt' => 'You are a D&D spellcasting advisor. Suggest appropriate spells for characters.',
        'user_prompt' => 'Suggest spells for a level {{level}} {{class}}.',
        'schema' => {
          'type' => 'object',
          'required' => ['cantrips', 'level_1_spells'],
          'properties' => {
            'cantrips' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => ['name', 'school'],
                'properties' => {
                  'name' => { 'type' => 'string' },
                  'school' => { 'type' => 'string' }
                }
              },
              'maxItems' => 4
            },
            'level_1_spells' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'required' => ['name', 'school'],
                'properties' => {
                  'name' => { 'type' => 'string' },
                  'school' => { 'type' => 'string' }
                }
              },
              'maxItems' => 4
            }
          }
        }
      }
    end

    def validate_template!(template)
      unless template.is_a?(Hash)
        raise ValidationError, 'Template must be a hash'
      end

      unless template['system_prompt'].is_a?(String)
        raise ValidationError, 'Template must include a system_prompt string'
      end

      unless template['user_prompt'].is_a?(String)
        raise ValidationError, 'Template must include a user_prompt string'
      end

      # Skip schema validation if response_format is string
      return if template['response_format'] == 'string'

      unless template['schema'].is_a?(Hash)
        raise ValidationError, 'Template must include a schema hash'
      end

      validate_schema!(template['schema'])
    end

    def validate_schema!(schema)
      unless schema['type'] == 'object'
        raise SchemaValidationError, 'Schema must be an object type'
      end

      unless schema['properties'].is_a?(Hash)
        raise SchemaValidationError, 'Schema must define properties'
      end

      unless schema['required'].is_a?(Array)
        raise SchemaValidationError, 'Schema must specify required fields'
      end

      # Validate that all required fields exist in properties
      missing_properties = schema['required'] - schema['properties'].keys
      unless missing_properties.empty?
        raise SchemaValidationError, "Required fields missing from properties: #{missing_properties.join(', ')}"
      end
    end

    def render_template(template, provider, context)
      # Create a copy of the template to avoid modifying the cached version
      rendered = template.deep_dup

      # Render the prompts using Mustache
      rendered['system_prompt'] = Mustache.render(template['system_prompt'], context)
      rendered['user_prompt'] = Mustache.render(template['user_prompt'], context)

      # For string responses, just return the rendered user_prompt
      return rendered['user_prompt'] if template['response_format'] == 'string'

      # Add provider-specific configuration if available
      if template["#{provider}_config"].is_a?(Hash)
        rendered['provider_config'] = template["#{provider}_config"]
      end

      rendered
    end

    def cache_key(request_type, provider)
      "prompt_template/#{request_type}/#{provider}"
    end
  end
end 