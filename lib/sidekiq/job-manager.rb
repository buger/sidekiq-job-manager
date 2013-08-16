begin
  require "sidekiq/web"
rescue LoadError
  # client-only usage
end

require "sidekiq/job-manager/version"
require "sidekiq/job-manager/middleware"
require "sidekiq/job-manager/web_extension"

module Sidekiq

  # Sets the maximum number of failures to track
  #
  # If the number of failures exceeds this number the list will be trimmed (oldest
  # failures will be purged).
  #
  # Defaults to 1000
  # Set to false to disable rotation
  def self.job_details_max_count=(value)
    @job_details_max_count = value
  end

  # Fetches the failures max count value
  def self.job_details_max_count
    return 1000 if @job_details_max_count.nil?

    @job_details_max_count
  end

  module JobManager
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::JobManager::Middleware
  end
end

if defined?(Sidekiq::Web)
  Sidekiq::Web.register Sidekiq::JobManager::WebExtension

  if Sidekiq::Web.tabs.is_a?(Array)
    # For sidekiq < 2.5
    Sidekiq::Web.tabs << "manager"
  else
    Sidekiq::Web.tabs["Job Manager"] = "manager"
  end
end
