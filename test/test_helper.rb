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
    jar.signed[:session_token] = session.signed_id
    cookies[:session_token] = jar[:session_token]
    session
  end

  def last_delivered_login_code
    job = enqueued_jobs.reverse.find { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
    ActiveJob::Arguments.deserialize(job["arguments"]).last[:params][:code]
  end
end

class ActionDispatch::IntegrationTest
  include SessionTestHelper
end
