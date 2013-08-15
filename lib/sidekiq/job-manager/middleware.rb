module Sidekiq
  module JobManager

    class Middleware
      include Sidekiq::Util
      attr_accessor :msg

      def call(worker, msg, queue)
        error = nil

        self.msg = msg
        yield
      rescue => e
        error = {
          :exception => e.class.to_s,
          :error => e.message,
          :backtrace => e.backtrace
        }

        raise e
      ensure
        data = {
          :finished_at => Time.now.strftime("%Y/%m/%d %H:%M:%S %Z"),
          :payload => msg,
          :queue => queue,
          :error => error
        }

        Sidekiq.redis do |conn|
          conn.zadd(:unique_jobs, 0, msg['class'])
          conn.lpush("#{msg['class']}:details", Sidekiq.dump_json(data))

          unless Sidekiq.job_details_max_count == false
            conn.ltrim("#{msg['class']}:details", 0, Sidekiq.job_details_max_count - 1)
          end
        end
      end

      private

      def last_try?
        !msg['retry'] || retry_count == max_retries - 1
      end

      def retry_count
        msg['retry_count'] || 0
      end

      def max_retries
        retry_middleware.retry_attempts_from(msg['retry'], default_max_retries)
      end

      def retry_middleware
        @retry_middleware ||= Sidekiq::Middleware::Server::RetryJobs.new
      end

      def default_max_retries
        Sidekiq::Middleware::Server::RetryJobs::DEFAULT_MAX_RETRY_ATTEMPTS
      end
    end
  end
end
