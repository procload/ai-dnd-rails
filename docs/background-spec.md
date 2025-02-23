# TODO: Turbo Stream Background Job System in Rails 8

This `todo.md` file merges two detailed plans into a single checklist. **We assume you already have a Rails 8 application** in which you want to replace synchronous content generation with an asynchronous background job system using **ActiveJob** and **Solid Queue**. Follow the steps below to integrate everything seamlessly.

---

## 1. Solid Queue Setup (If Not Already Installed)

- [x] **Install & Configure Solid Queue** _(Completed 2025-02-23)_
  - [x] Add `gem 'solid_queue'` to your `Gemfile`.
  - [x] Run `bundle install`.
  - [x] In `config/application.rb`, set:
    ```ruby
    config.active_job.queue_adapter = :solid_queue
    ```
  - [x] Confirm installation (e.g., `rails about` or `bundle info solid_queue`).

---

## 2. Basic Job to Verify Queue Functionality

> Even though you have an existing app, it's helpful to create a **test job** to confirm that Solid Queue works correctly before converting your synchronous flows.

- [x] **Generate and Test a Basic Job** _(Completed 2025-02-23)_

  - [x] Run `rails g job hello_world`.
  - [x] In `app/jobs/hello_world_job.rb`, implement `perform` to log `"Hello World from Solid Queue!"`.
  - [x] Create a quick route & controller action to enqueue the job:

    ```ruby
    # config/routes.rb
    get '/test_hello_world_job', to: 'test_jobs#hello_world'

    # app/controllers/test_jobs_controller.rb
    class TestJobsController < ApplicationController
      def hello_world
        HelloWorldJob.perform_later
        render plain: "HelloWorldJob enqueued"
      end
    end
    ```

  - [x] Test endpoint in browser, confirmed job runs and logs message.

---

## 3. Concurrency Limit & Basic Job Logic

> Now we'll ensure each user can only run up to 10 concurrent background jobs. This also sets up retry logic and the basic "perform" flow you'll reuse for all content-generation jobs.

- [x] **3.1 Implement a `UserJobCounter` Service** _(Completed 2025-02-23)_

  - [x] Create `app/services/user_job_counter.rb` with thread-safe implementation using `Concurrent::Map`
  - [x] Implement increment, decrement, and count_for methods
  - [x] Add configuration for max concurrent jobs
  - [x] Add proper error handling and logging

- [x] **3.2 Enforce Concurrency Limit Before Enqueuing** _(Completed 2025-02-23)_

  - [x] Created JobLimiting concern for controllers
  - [x] Implemented check_job_limit! method
  - [x] Added proper error handling and user feedback
  - [x] Tested with TestJobsController

- [x] **3.3 Decrement on Completion or Failure** _(Completed 2025-02-23)_

  - [x] Implemented in ApplicationJob base class
  - [x] Added proper error handling
  - [x] Ensured cleanup in all cases
  - [x] Tested with TestConcurrentJob

- [x] **3.4 Exponential Backoff & Retries** _(Completed 2025-02-23)_
  - [x] Configured retries in ApplicationJob
  - [x] Implemented exponential backoff
  - [x] Added proper error logging
  - [x] Tested retry functionality

---

## 4. Cancellation Flow

> Give users the ability to cancel an in-progress or queued job and skip retries.

- [ ] **4.1 Add a Cancel Route & Controller Action**

  - [ ] In `config/routes.rb`:
    ```ruby
    post '/jobs/:id/cancel', to: 'jobs#cancel', as: :cancel_job
    ```
  - [ ] In `app/controllers/jobs_controller.rb`:
    ```ruby
    class JobsController < ApplicationController
      def cancel
        # For example, store "canceled" job IDs in a simple in-memory store or Redis
        JobCancellation.mark_canceled(params[:id])
        render plain: "Job cancellation requested"
      end
    end
    ```

- [ ] **4.2 Track Canceled Job IDs**

  - [ ] In `app/services/job_cancellation.rb`:

    ```ruby
    class JobCancellation
      @@canceled_jobs = Set.new

      def self.mark_canceled(job_id)
        @@canceled_jobs << job_id.to_s
      end

      def self.canceled?(job_id)
        @@canceled_jobs.include?(job_id.to_s)
      end
    end
    ```

- [ ] **4.3 Check `canceled?` in the Job**

  - [ ] In your job's `perform`:

    ```ruby
    def perform(user_id, job_params)
      if JobCancellation.canceled?(job_id)
        Rails.logger.info "Job #{job_id} canceled before work!"
        return
      end

      # Otherwise, proceed with the job's work
      # ...
    ensure
      UserJobCounter.decrement(user_id)
    end

    private

    def job_id
      provider_job_id || self.job_id # depending on how your queue adapter sets the ID
    end
    ```

  - [ ] Ensure that if `canceled?` returns `true`, you skip work and do not retry.

---

## 5. Basic Turbo Stream UI & Controller Wiring

> Now that we can enqueue and cancel jobs, we want to show real-time updates using **Turbo Streams**.

- [ ] **5.1 Wrap Sections in Turbo Frames**

  - [ ] In your relevant view(s), wrap the section(s) that will update in `<turbo-frame id="my-content">` or similar.
  - [ ] Example:
    ```erb
    <turbo-frame id="my-content">
      <!-- Initial state or content goes here -->
    </turbo-frame>
    ```

- [ ] **5.2 Show a Loading Indicator on Enqueue**

  - [ ] When you enqueue the job, render a Turbo Stream response that replaces `my-content` with a partial containing a spinner and a Cancel button (pointing to `cancel_job_path`).
  - [ ] Example partial `app/views/jobs/_loading_indicator.html.erb`:
    ```erb
    <div id="loading-indicator">
      <span>Loading...</span>
      <%= link_to "Cancel", cancel_job_path(job_id), method: :post, data: { turbo_stream: true } %>
    </div>
    ```

- [ ] **5.3 Cancel Button Integration**

  - [ ] Ensure the Cancel link calls your cancel route. On success, you can render another Turbo Stream partial ("Job canceled") for 5 seconds.
  - [ ] Or, use StimulusJS fetch to handle it in JavaScript. Either way, confirm the job is actually canceled in the logs.

- [ ] **5.4 Handle Job Completion**

  - [ ] In the job, after finishing work, broadcast a Turbo Stream update:
    ```ruby
    Turbo::StreamsChannel.broadcast_replace_to(
      "my-content", # stream name or identifier
      target: "my-content",
      partial: "jobs/completed_content",
      locals: { result: "Generated content" }
    )
    ```
  - [ ] In `app/views/jobs/_completed_content.html.erb`, place the final content. This partial replaces the loading indicator.

- [ ] **5.5 Verify Turbo Stream Responses**
  - [ ] Manually test in the browser. Enqueue a job → see the loading indicator → after job completes, see the new content appear.
  - [ ] Cancel mid-way → see "canceled" partial.
  - [ ] Check logs that the job was indeed canceled or completed.

---

## 5A. Solid Cable Integration

> While Turbo Streams handle basic updates, we'll use Solid Cable for more granular real-time progress updates.

- [ ] **5A.1 Configure Solid Cable**

  - [ ] Verify `solid_cable` gem is installed (included by default in Rails 8)
  - [ ] Configure cable database in `config/database.yml`:
    ```yaml
    development:
      cable:
        <<: *default
        database: storage/development_cable.sqlite3
        migrations_paths: db/cable_migrate
    ```
  - [ ] Run `bin/rails db:prepare` to create cable database

- [ ] **5A.2 Create Progress Channel**

  - [ ] Generate channel: `bin/rails g channel CharacterProgress`
  - [ ] Implement streaming updates in the job:
    ```ruby
    def broadcast_progress(message, percentage)
      broadcast_to(
        "character_progress_#{arguments.first}",
        {
          status: "processing",
          message: message,
          percentage: percentage
        }
      )
    end
    ```

- [ ] **5A.3 Implement Client-Side Updates**

  - [ ] Create Stimulus controller for progress updates
  - [ ] Add progress bar and status message to view
  - [ ] Handle connection/disconnection lifecycle
  - [ ] Process incoming messages

- [ ] **5A.4 Test Real-Time Updates**
  - [ ] Verify progress updates appear in real-time
  - [ ] Confirm messages are stored in cable database
  - [ ] Test message cleanup after retention period

---

## 6. Session Tracking & Page Refresh

> Preserve which jobs are currently loading or canceled if the user refreshes the page.

- [ ] **6.1 Track Active Job IDs in Session**

  - [ ] When the user enqueues a job, add `job_id` to `session[:active_job_ids] ||= []`.
  - [ ] On completion or cancellation, remove it from `session[:active_job_ids]`.

- [ ] **6.2 Restore Indicators on Refresh**
  - [ ] On page load, check `session[:active_job_ids]`. For each ID still in that array, render the loading indicator partial again.
  - [ ] If the job has actually completed/canceled behind the scenes, remove it from the session.

---

## 7. Debounce, ARIA, Logging, and Minimal Testing

> Polishing and accessibility.

- [ ] **7.1 Debounce the Submit Button**

  - [ ] Create a Stimulus controller (e.g., `debounce_controller.js`).
  - [ ] Set a 300ms debounce so the user can't spam the button to create multiple jobs simultaneously.

- [ ] **7.2 Add ARIA Live Regions**

  - [ ] In the loading indicator partial, use `aria-live="polite"` or `assertive` so screen readers announce status changes.

- [ ] **7.3 Rails Logging**

  - [ ] On each event (enqueue, start, complete, failure, cancel), log a brief message. No DB tracking required.

- [ ] **7.4 Minimal RSpec or Minitest Coverage**
  - [ ] Concurrency limit: ensure the 11th job fails if 10 are already active.
  - [ ] Retries: ensure a forced failure tries up to 3 times.
  - [ ] Cancellation: ensure a canceled job does not retry.
  - [ ] Turbo Streams: ensure partials update correctly.

---

## 8. Final Review & Manual Testing

- [ ] **Manual Testing Checklist**
  - [ ] **Multiple Pieces of Content**: Convert each previously synchronous content generation flow to use the new background job approach, so you can enqueue multiple content pieces in parallel.
  - [ ] **Concurrency**: Attempt to enqueue more than 10 jobs as the same user → verify block.
  - [ ] **Cancellation**: Cancel mid-processing → confirm no retries.
  - [ ] **Failures**: Force job failures, watch retries, final error display.
  - [ ] **Page Refresh**: Check that loading indicators remain if the job is still in progress.
  - [ ] **Turbo Streams**: Test from multiple browsers/logins to see updates broadcast in real time.
  - [ ] **Accessibility**: Confirm ARIA live regions are read by screen readers if possible.

---

### Additional Notes

- **Integration Into Existing App**: These steps assume you can modify existing controllers and views. You'll wrap previously synchronous logic (e.g., one-by-one content generation) inside background jobs and use Turbo Streams to update UI elements.
- **Scaling & Production**: For large workloads, consider how many Solid Queue workers you'll run, how you'll scale concurrency, and any distributed caching for concurrency counters.
- **Customize**: The concurrency limit, cancel flow, and session tracking can be adapted to your exact data model (e.g., referencing `current_user.id` or a specific multi-tenant approach).

---

**Use this list as your high-level blueprint and check off tasks as you integrate the new system into your existing Rails app.**
