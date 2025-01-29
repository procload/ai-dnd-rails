# D&D Character Generator

A Ruby on Rails 8 application for generating Dungeons & Dragons characters. This project accompanies a blog post series about building AI-powered applications with Rails.

## Requirements

- Ruby 3.2 or newer
- Rails 8.0.1
- PostgreSQL 14 or newer
- Node.js & Yarn (for asset compilation)

## Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/dnd-rails.git
   cd dnd-rails
   ```

2. Install dependencies:

   ```bash
   bundle install
   ```

3. Setup the database:

   ```bash
   bin/rails db:create db:migrate
   ```

4. Start the development server:

   ```bash
   bin/dev
   ```

5. Visit http://localhost:3000 in your browser

## Project Structure

- `/app` - Application code (models, views, controllers)
- `/config` - Configuration files
- `/db` - Database migrations and schema
- `/docs` - Documentation and blog posts
  - `/docs/articles` - Blog post content
  - `/docs/working-plan.md` - Implementation plan

## Features

- Character creation with D&D 5e rules
- Real-time updates using Hotwire
- AI-powered character background generation
- Equipment and spell management
- Character sheet generation

## Contributing

This is a demonstration project accompanying a blog post series. While we welcome issues and discussions, we may not accept pull requests that deviate from the educational goals of the series.

## License

This project is available as open source under the terms of the MIT License.

## Related Blog Posts

- [Rails & AI: Building Our Character Generator](link-to-post)
