require "test_helper"

module Llm
  class FactoryTest < ActiveSupport::TestCase
    setup do
      @original_provider = Rails.configuration.llm.provider
      Rails.configuration.llm.provider = :mock
    end

    teardown do
      Rails.configuration.llm.provider = @original_provider
    end

    test "creates mock provider in test environment" do
      provider = Llm::Factory.create_provider
      assert_kind_of Llm::Providers::Mock, provider
    end

    test "raises error for unknown provider" do
      Rails.configuration.llm.provider = :unknown
      
      assert_raises Llm::Service::ConfigurationError do
        Llm::Factory.create_provider
      end
    end
  end
end 
