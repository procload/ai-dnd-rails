ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "json"
require "webmock/minitest"

# Load all service files for testing
Dir[Rails.root.join("app/services/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def setup
      super
      
      # Ensure we're in test environment
      assert_equal "test", Rails.env
      
      # Ensure test fixtures directory exists
      fixtures_dir = Rails.root.join('test', 'fixtures', 'files')
      assert Dir.exist?(fixtures_dir), "Test fixtures directory does not exist: #{fixtures_dir}"
      
      # Ensure required JSON fixtures exist and are valid
      %w[background.json equipment.json spells.json].each do |fixture|
        fixture_path = fixtures_dir.join(fixture)
        assert File.exist?(fixture_path), "Required fixture missing: #{fixture_path}"
        assert_json_loadable(fixture_path)
      end
    end

    private

    def assert_json_loadable(path)
      content = File.read(path)
      parsed = ::JSON.parse(content)
      assert parsed.is_a?(Hash), "JSON content should be an object in: #{path}"
    rescue ::JSON::ParserError => e
      flunk "Invalid JSON in fixture #{path}: #{e.message}"
    end
  end
end
