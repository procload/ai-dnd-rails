# Rails 8 AI-Powered Spellbook Generator

A Ruby on Rails 8 application for generating Dungeons & Dragons characters with AI-powered background generation. This project accompanies a blog post series about building AI-powered applications with Rails.

## Requirements

- Ruby 3.3.5
- Rails 8.0.1
- PostgreSQL (for database)
- Redis (for Solid Queue and caching)
- Node.js & Yarn (for asset compilation)

## Key Technologies

- Rails 8.0.1 with modern defaults
- Solid Queue for background job processing
- Solid Cache for caching
- Solid Cable for real-time features
- Hotwire (Turbo & Stimulus) for dynamic interfaces
- Tailwind CSS for styling
- Propshaft asset pipeline
- Anthropic Claude API for AI content generation
- AWS S3 for image storage
- Kamal for Docker-based deployment

## Setup

1. Clone the repository and install dependencies:

   ```bash
   bundle install
   yarn install
   ```

2. Configure environment variables:

   ```bash
   cp .env.example .env
   ```

   Required environment variables include:

   - LLM provider settings (Anthropic/OpenAI)
   - AWS credentials for S3
   - Database configuration

3. Setup the database:

   ```bash
   bin/rails db:create db:migrate
   bin/rails db:seed  # Loads initial spellbook data
   ```

4. Start the development servers:

   ```bash
   bin/dev
   ```

## Development

- Run tests: `bin/rails test`
- Check security: `bundle exec brakeman`
- Run linter: `bundle exec rubocop`

## Project Structure

- `/app`
  - `/models` - Core spellbook and magic system models
  - `/services` - Service objects for LLM integration
  - `/views` - Hotwire-enhanced templates
  - `/controllers` - RESTful controllers
  - `/jobs` - Background jobs (using Solid Queue)
- `/config` - Application configuration
- `/db` - Database migrations and seeds
- `/test` - Test suite

## Features

### Spellbook Generation

- AI-powered spell descriptions
- Dynamic spell combinations
- Custom magical effects
- Spell categorization and organization

### AI Integration

- Claude 3 Sonnet integration for content generation
- Background processing for AI tasks
- Fallback providers (OpenAI/Azure)

### Technical Features

- Modern Rails 8 architecture
- Real-time updates via Hotwire
- Background job processing with Solid Queue
- Docker-based deployment with Kamal
- AWS S3 integration for assets
- Comprehensive test suite

## License

This project is available as open source under the terms of the MIT License.

## Related Blog Posts

1. [Rails & AI: Building Our Character Generator](link-to-post-1) - Initial setup and core mechanics
2. [The Art of LLM Services in Rails](link-to-post-2) - Coming soon
