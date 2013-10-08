require 'slim'

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

          render(:erb, File.read(File.join(view_path, "manager.erb")))
        end

        app.get "/manager/worker/:name" do |name|
          @worker = name
          view_path = File.join(File.expand_path("..", __FILE__), "views")

          @count = (params[:count] || 50).to_i
          (@current_page, @total_size, @messages) = page("#{name}:details", params[:page], @count)
          @messages = @messages.map { |msg| Sidekiq.load_json(msg) }

          render(:erb, File.read(File.join(view_path, "job_details.erb")))
        end

        app.post "/manager/worker/:name/remove" do |name|
          Sidekiq.redis {|c|
            c.multi do
              c.del("#{name}:details")
              c.zrem("unique_jobs", name)
            end
          }

          redirect "#{root_path}manager"
        end

        app.post "/manager/add_to_queue" do
          msg = {
            'class' => params[:worker],
            'args' => params[:args].split(','),
            'queue' => params[:queue] || "default",
            'retry' => false
          }

          Sidekiq::Client.push(msg)      
        end
      end
    end
  end
end
