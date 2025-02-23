# D&D Rails Application Transition Specification

## Overview

This document outlines the plan to transition the D&D character generator application from @dnd-rails to our current directory while preserving all functionality and incorporating modern Rails 8 features.

## Current Structure Analysis

The @dnd-rails application is a D&D character generator with:

- Character model with extensive game mechanics
- AI-powered background generation
- Image generation capabilities
- Modern Rails 8 features (Solid Queue, Propshaft, etc.)
- Hotwire/Turbo integration
- Test coverage
- CI/CD configuration

## Current State & Issues

### Database Issues

1. Migration Conflicts:

   - Duplicate migration version (20250222124505)
   - Pending migration for race attribute
   - Missing character_portraits table

2. Model Issues:
   - Race attribute not defined on Character model
   - Character portrait associations need setup
   - Ability scores handling needs refinement

### Service Layer Issues

1. Image Generation Service:

   - Missing ImageGeneration::ProviderError class
   - Inconsistent error class namespacing
   - Background job configuration needs fixing

2. LLM Service:
   - Working as expected
   - All prompt templates in place
   - Error handling properly configured

### Frontend Status

1. View Layer:

   - All partials implemented
   - Turbo Stream responses working
   - Loading states implemented
   - Form handling working

2. Asset Pipeline:
   - Tailwind CSS configured and working
   - JavaScript dependencies set up
   - Stimulus controllers functioning

## Transition Phases

### Phase 1: Configuration & Environment (✓ COMPLETED)

1. Configuration files merged:

   - Ruby version set to 3.3.5
   - Gemfile dependencies updated
   - Environment variables configured
   - Database configuration set

2. Application configuration updated:
   - Application.rb configured
   - Environment-specific configs set
   - Initializers in place

### Phase 2: Core Model Migration (IN PROGRESS)

1. Database Schema:

   - Fix migration versioning
   - Add missing tables
   - Complete pending migrations

2. Model Implementation:
   - Add missing attributes
   - Set up associations
   - Validate functionality

### Phase 3: Service Layer (IN PROGRESS)

1. Error Handling:

   - Create missing error classes
   - Fix namespacing issues
   - Update error references

2. Background Jobs:
   - Configure Solid Queue
   - Fix portrait generation job
   - Test job processing

### Phase 4: Frontend Layer (✓ COMPLETED)

1. View Implementation:

   - All partials created
   - Turbo integration working
   - Loading states implemented

2. Asset Configuration:
   - Tailwind CSS set up
   - JavaScript dependencies configured
   - Stimulus controllers working

## Key Considerations

### Database Compatibility

- Ensure migration versioning is unique
- Validate all required tables exist
- Verify column types and constraints

### Error Handling

- Maintain consistent error class hierarchy
- Ensure proper namespacing
- Validate error propagation

### Background Jobs

- Verify job queuing
- Test job execution
- Monitor job status

## Testing Strategy

### Continuous Integration

- Add tests for new functionality
- Verify existing test coverage
- Monitor error handling

### Manual Testing Checklist

- Character creation flow
- AI-powered generation features
- Image generation
- Real-time updates
- Error handling

## Success Criteria

1. All database migrations run successfully
2. Error handling works consistently
3. Background jobs process correctly
4. Frontend features work smoothly
5. Tests pass
6. Documentation updated

## Timeline Update

- Database fixes: 1 day
- Error handling: 1 day
- Background jobs: 1 day
- Testing & Verification: 1 day

Total remaining time: 4 working days

## Rollback Plan

- Maintain separate branches for each phase
- Document database state after each migration
- Keep backup of original application code
- Test rollback procedures

## Next Steps

1. Create new branch for transition
2. Begin with Phase 1 configuration migration
3. Set up CI/CD pipeline
4. Start incremental model migration

## Background Job Processing

### SolidQueue Configuration

- Separate queue database configured in `database.yml`
- Queue-specific migrations located in `db/queue_migrate`
- Development environment configured for async job processing
- Connection pool size set to 5
- Polling interval: 1 second
- Dispatch interval: 0.5 seconds

### Job Processing Flow

1. Jobs are enqueued through ActiveJob interface
2. SolidQueue processes jobs asynchronously in development
3. Jobs are tracked in the queue database
4. Failed jobs are stored for retry/inspection

### Database Structure

#### Primary Database

- Character data
- Active Storage attachments
- Action Text content

#### Queue Database

- SolidQueue tables for job management
- Separate migration path for queue-specific schema

## Character Generation Features

### Portrait Generation

- Uses image generation service
- Stores images using Active Storage
- Processes in background using SolidQueue
- Supports multiple portraits per character

### Background Generation

- Uses LLM service for content generation
- Processes in background
- Updates via Turbo Streams
- Includes structured sections:
  - Early life
  - Pivotal moments
  - Recent history
  - Unresolved mysteries

### Personality Details (In Progress)

- Uses LLM service
- Background job processing
- Turbo Stream updates
- Structured personality traits

## Service Architecture

### LLM Service

- Supports multiple providers (Anthropic, OpenAI)
- Structured prompt templates
- Error handling and retries
- Async processing via SolidQueue

### Image Generation Service

- Multiple provider support
- Background job processing
- Active Storage integration
- Error handling with retries

## Development Environment

### Configuration

- Environment variables via dotenv
- Separate development databases
- Async job processing enabled
- Debug logging configured

### Background Jobs

- SolidQueue for job processing
- Automatic job execution in development
- Job monitoring and debugging tools
- Failed job handling

## Testing Strategy

### Unit Tests

- Model validations and methods
- Service object functionality
- Job processing flow

### Integration Tests

- Character generation workflow
- Background job completion
- Turbo Stream updates

### System Tests

- End-to-end character creation
- Image generation process
- Real-time updates
