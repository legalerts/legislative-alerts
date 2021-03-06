require 'dotenv'
Dotenv.load(".env.test")

ENV['RAILS_ENV'] ||= 'test'
ENV['OPENSTATES_API_KEY'] ||= 'no-such-key'

require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
require 'webmock/rspec'
ActiveRecord::Migration.maintain_test_schema!

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

WebMock.disable_net_connect!(allow: 'openstates.org')

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods

  [:controller, :view, :request].each do |type|
    config.include ::Rails::Controller::Testing::TestProcess, :type => type
    config.include ::Rails::Controller::Testing::TemplateAssertions, :type => type
    config.include ::Rails::Controller::Testing::Integration, :type => type
  end

  config.after do
    Rails.cache.clear
  end
end
