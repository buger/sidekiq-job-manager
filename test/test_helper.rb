Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "minitest/autorun"
require "minitest/spec"
require "minitest/mock"

# FIXME Remove once https://github.com/mperham/sidekiq/pull/548 is released.
class String
  def blank?
    self !~ /[^[:space:]]/
  end
end

require "rack/test"

require "celluloid"
require "sidekiq"
require "sidekiq-job-manager"
require "sidekiq/processor"
require "sidekiq/fetch"
require "sidekiq/cli"
require "mock_redis"

Celluloid.logger = nil
Sidekiq.logger.level = Logger::ERROR

REDIS = ConnectionPool.new(:size => 1, :timeout => 5) { MockRedis.new }
