ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# PVAR runs are enqueued to Sidekiq; tests must never hit Redis or shell out to R, so jobs are
# recorded (assertable via PvarJob.jobs) instead of executed. Sidekiq 8 testing API.
Sidekiq.testing!(:fake)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
