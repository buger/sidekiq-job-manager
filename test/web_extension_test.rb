require "test_helper"
require "sidekiq/web"

module Sidekiq
  describe "WebExtension" do
    include Rack::Test::Methods

    def app
      Sidekiq::Web
    end

    before do
      Sidekiq.redis = REDIS
      Sidekiq.redis {|c| c.flushdb }
    end

    it 'can display home with manager tab' do
      get '/'

      last_response.status.must_equal 200
      last_response.body.must_match /Sidekiq/
      last_response.body.must_match /Job Manager/
    end

    it 'can display jobs page without any failures' do
      get '/manager'
      last_response.status.must_equal 200
      last_response.body.must_match /Recent jobs/
      last_response.body.must_match /No jobs found/
    end

    describe 'when there are jobs' do
      before do
        create_sample_failure
        get '/manager'
      end

      it 'should be successful' do
        last_response.status.must_equal 200
      end

      it 'can display failures page with failures listed' do
        
      end
    end

    def create_sample_failure
      data = {
        :finished_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
        :payload => { :args => ["test", 5], :class => 'Worker' },
        :error => {
          :exception => "ArgumentError",
          :error => "Some new message",
          :backtrace => ["path/file1.rb", "path/file2.rb"]
        },
        :queue => 'default'
      }

      Sidekiq.redis do |c|
        c.multi do
          c.zadd(:unique_jobs, 0, data[:payload][:class])
          c.lpush("#{data[:payload][:class]}:details", Sidekiq.dump_json(data))
        end
      end
    end

    def unique_jobs_count
      Sidekiq.redis { |conn|conn.zcard('unique_jobs') } || 0
    end

  end
end
