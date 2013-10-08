# Used for debugging Web UI
# 
#    bundle exec rackup config.ru
#
require 'sidekiq'
require 'sidekiq/web'
require './lib/sidekiq-job-manager'
require 'mock_redis'

REDIS = ConnectionPool.new(:size => 1, :timeout => 5) { MockRedis.new }
Sidekiq.redis = REDIS
Sidekiq.redis {|c| c.flushdb }


100.times do |t|
  data = {
    :finished_at => Time.at(Time.now.to_i-rand(60*t)).strftime("%Y/%m/%d %H:%M:%S %Z"),
    :payload => { :args => ["test", rand(10)], :class => "Worker#{rand(5)}" },    
    :queue => 'default'
  }

  if rand(3) == 0
    data[:error] = {
        :exception => "ArgumentError",
        :error => "Some new message",
        :backtrace => ["path/file1.rb", "path/file2.rb"]
    }
  end

  Sidekiq.redis do |c|
    c.multi do
      c.zadd(:unique_jobs, 0, data[:payload][:class])
      c.lpush("#{data[:payload][:class]}:details", Sidekiq.dump_json(data))
    end
  end
end

run Sidekiq::Web
