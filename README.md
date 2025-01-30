# D&D Character Generator

A Ruby on Rails 8 application for generating Dungeons & Dragons characters with AI-powered background generation. This project accompanies a blog post series about building AI-powered applications with Rails.

## Requirements

- Ruby 3.2 or newer
- Rails 8.0.1
- PostgreSQL 14 or newer
- Node.js 18+ & Yarn 1.22+ (for asset compilation)
- Redis (for background job processing)

## Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/dnd-rails.git
   cd dnd-rails
   ```

2. Install dependencies:

   ```bash
   bundle install
   yarn install
   ```

3. Configure environment variables:

   ```bash
   cp .env.example .env
   ```

   Edit `.env` with your database and Redis configuration.

4. Setup the database:

   ```bash
   bin/rails db:create db:migrate
   bin/rails db:seed  # Loads initial D&D data
   ```

5. Start the development servers:

   ```bash
   bin/dev  # Starts Rails, asset compilation, and Redis
   ```

6. Visit http://localhost:3000 in your browser

## Development

- Run tests: `bin/rails test`
- Run the linter: `bin/rails lint`
- Generate ERD: `bin/rails erd`

## Project Structure

- `/app`
  - `/models` - Core game mechanics and character logic
  - `/services` - Service objects including LLM integration
  - `/views` - Hotwire-enhanced templates
  - `/controllers` - RESTful resource controllers
  - `/jobs` - Background job processors
- `/config` - Application configuration
- `/db` - Database migrations and seeds
- `/docs` - Documentation and blog posts
  - `/docs/articles` - Blog post content
  - `/docs/working-plan.md` - Implementation plan
- `/mock` - Mock service responses for development

## Features

### Character Creation

- D&D 5e rules implementation
- Ability score generation and modification
- Class and race selection
- Equipment management
- Spell selection (for spellcasting classes)

### AI Integration

- Background story generation
- Character personality traits
- Mock LLM service for development
- Real-time updates via Hotwire

### Technical Features

- Hotwire (Turbo Frames & Streams) for dynamic updates
- PostgreSQL JSON(B) for flexible data storage
- Background job processing
- Service-oriented architecture for LLM integration

## Contributing

This is a demonstration project accompanying a blog post series. While we welcome issues and discussions, we may not accept pull requests that deviate from the educational goals of the series.

## License

This project is available as open source under the terms of the MIT License.

## Related Blog Posts

1. [Rails & AI: Building Our Character Generator](link-to-post-1) - Initial setup and core mechanics
2. [The Art of LLM Services in Rails](link-to-post-2) - Coming soon
