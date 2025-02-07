# frozen_string_literal: true

module Llm
  # Service for managing and generating prompts for LLM providers
  class PromptService
    class Error < StandardError; end
    class TemplateNotFoundError < Error; end
    class ValidationError < Error; end

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
      render_template(template, context)
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
      filename = "#{request_type}.yml"
      [
        # Environment-specific provider template
        Rails.root.join('config', 'prompts', Rails.env, provider.to_s, filename),
        # Provider-specific template
        Rails.root.join('config', 'prompts', provider.to_s, filename),
        # Environment-specific default template
        Rails.root.join('config', 'prompts', Rails.env, 'default', filename),
        # Default template
        Rails.root.join('config', 'prompts', 'default', filename)
      ]
    end

    def load_default_template(request_type)
      path = Rails.root.join('config', 'prompts', 'default', "#{request_type}.yml")
      YAML.load_file(path)
    rescue Errno::ENOENT
      raise TemplateNotFoundError, "No default template found for #{request_type}"
    end

    def validate_template!(template)
      required_keys = %w[system_prompt user_prompt]
      missing_keys = required_keys - template.keys

      unless missing_keys.empty?
        raise ValidationError, "Template missing required keys: #{missing_keys.join(', ')}"
      end

      if template['schema']
        # TODO: Add JSON schema validation when we implement it
      end

      template
    end

    def render_template(template, context)
      {
        'system_prompt' => render_content(template['system_prompt'], context),
        'user_prompt' => render_content(template['user_prompt'], context)
      }
    end

    def render_content(content, context)
      return content if context.empty?

      # Use Mustache for template rendering
      Mustache.render(content, context)
    end

    def cache_key(request_type, provider)
      ["prompt_template", provider, request_type, template_version(request_type, provider)].join('/')
    end

    def template_version(request_type, provider)
      # TODO: Implement versioning strategy
      # For now, we'll use the file mtime as a simple cache buster
      paths = template_paths(request_type, provider)
      path = paths.find { |p| File.exist?(p) }
      path ? File.mtime(path).to_i : 'default'
    end
  end
end 