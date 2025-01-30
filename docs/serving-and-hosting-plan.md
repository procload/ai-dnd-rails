# MVP Hosting Plan for D&D Character Generator

## Quick Launch Strategy

Our goal is to get a working demo deployed with minimal cost and complexity. We'll use DigitalOcean for its simplicity and reasonable pricing.

### Initial Setup Requirements

1. Basic Infrastructure

   - 1GB RAM Droplet ($5/month)
   - Basic Managed PostgreSQL ($15/month)
   - No Redis initially (will implement if needed)

2. Essential Gems
   ```ruby
   # Gemfile additions
   gem 'kamal'     # Deployment
   gem 'pg'        # PostgreSQL
   ```

### Pre-Deploy Checklist

- [ ] Configure database.yml for production
- [ ] Set up master.key and credentials
- [ ] Create production database
- [ ] Test asset compilation locally
- [ ] Configure domain (if using)

### Deployment Steps

1. Initial Server Setup

   ```bash
   # Generate deployment config
   kamal setup

   # Deploy application
   kamal deploy
   ```

2. Database Setup
   ```bash
   # Run migrations
   kamal exec rails db:migrate
   ```

### MVP Rate Limiting

Instead of Redis, we'll start with a simple database-backed rate limiter:

```ruby
# app/models/request_log.rb
class RequestLog < ApplicationRecord
  def self.within_limits?(ip)
    count = where(ip: ip)
      .where('created_at > ?', 1.hour.ago)
      .count

    count < ENV.fetch('HOURLY_LIMIT', 10)
  end
end
```

### Cost Breakdown

Monthly Total: ~$20

- Droplet: $5
- Database: $15
- No additional services initially

### Future Considerations

Only implement these if usage demands:

1. Redis for rate limiting
2. Background job processing
3. Additional server resources
4. CDN integration

### Monitoring MVP

Use DigitalOcean's built-in monitoring:

- CPU usage
- Memory usage
- Disk I/O
- Basic error logging

### Quick Launch Commands

```bash
# One-time setup
kamal setup

# Deploy
kamal deploy

# Check logs
kamal logs

# Run migrations
kamal exec rails db:migrate
```

This MVP approach gets us running quickly while maintaining the ability to scale if needed. We can add complexity only when usage patterns demand it.
