module Sidekiq
  module JobManager
    module WebExtension

      def self.registered(app)
        app.get "/manager" do
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @jobs = Sidekiq.redis { |conn|conn.zrange('unique_jobs',0,-1) } || []

          @jobs.map! do |job|
            last_call = Sidekiq.redis { |conn|conn.lindex("#{job}:details",0) }

            {
              name: job,
              last_call: Sidekiq.load_json(last_call)
            }
          end

          render(:slim, File.read(File.join(view_path, "manager.slim")))
        end

        app.get "/manager/worker/:name" do |name|
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @count = (params[:count] || 25).to_i
          (@current_page, @total_size, @messages) = page("#{name}:details", params[:page], @count)
          @messages = @messages.map { |msg| Sidekiq.load_json(msg) }

          render(:slim, File.read(File.join(view_path, "job_details.slim")))
        end

        app.post "/manager/remove" do
          Sidekiq.redis {|c|
            c.multi do
              c.del("failed")
              c.set("stat:failed", 0) if params["counter"]
            end
          }

          redirect "#{root_path}manager"
        end
      end
    end
  end
end
