ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/test_helpers/**/*.rb")].each { require it }

module ActiveSupport
  class TestCase
    include LlmStubbing

    parallelize(workers: :number_of_processors)

    fixtures :all
  end
end

module SessionTestHelper
  def sign_in_as(user)
    session = user.sessions.create!
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id
    cookies[:session_id] = jar[:session_id]
    session
  end
end

class ActionDispatch::IntegrationTest
  include SessionTestHelper
end
