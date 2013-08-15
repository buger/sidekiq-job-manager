require "test_helper"
require "sidekiq"

module Sidekiq
  module JobManager
    describe "Middleware" do
      before do
        $invokes = 0
        Sidekiq.job_details_max_count = nil
        @boss = MiniTest::Mock.new
        @processor = ::Sidekiq::Processor.new(@boss)
        Sidekiq.server_middleware {|chain| chain.add Sidekiq::JobManager::Middleware }
        Sidekiq.redis = REDIS
        Sidekiq.redis { |c| c.flushdb }
        Sidekiq.instance_eval { @failures_default_mode = nil }
      end

      TestException = Class.new(StandardError)
      ShutdownException = Class.new(Sidekiq::Shutdown)

      class MockWorker
        include Sidekiq::Worker

        def perform(*args)
          $invokes += 1

          if args[1] != "success"
            raise ShutdownException.new if args[0] == "shutdown"
            raise TestException.new("failed!")
          end
        end
      end

      class MockWorker1 < MockWorker
      end

      class MockWorker2 < MockWorker
      end

      it 'raises an error when failures_default_mode is configured incorrectly' do
        assert_raises ArgumentError do
          Sidekiq.failures_default_mode = 'exhaustion'
        end
      end

      it 'defaults failures_default_mode to all' do
        assert_equal :all, Sidekiq.failures_default_mode
      end

      it 'records all failures by default' do
        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'])

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 1, failures_count
        assert_equal 1, $invokes
      end

      it 'records all failures if explicitly told to' do
        msg = create_work('class' => MockWorker.to_s, 'args' => ["myarg"], 'failures' => true)

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 1, failures_count
        assert_equal 1, $invokes
      end

      it "doesn't record internal shutdown failure" do
        msg = create_work('class' => MockWorker.to_s, 'args' => ['shutdown'], 'failures' => true)

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        @processor.process(msg)
        @boss.verify

        assert_equal 0, failures_count
        assert_equal 1, $invokes
      end

      it "doesn't record failure if failures disabled" do
        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'failures' => false)

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 0, failures_count
        assert_equal 1, $invokes
      end

      it "doesn't record failure if going to be retired again and configured to track exhaustion by default" do
        Sidekiq.failures_default_mode = :exhausted

        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'retry' => true )

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 0, failures_count
        assert_equal 1, $invokes
      end


      it "doesn't record failure if going to be retired again and configured to track exhaustion" do
        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'retry' => true, 'failures' => 'exhausted')

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 0, failures_count
        assert_equal 1, $invokes
      end

      it "records failure if failing last retry and configured to track exhaustion" do
        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'retry' => true, 'retry_count' => 24, 'failures' => 'exhausted')

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 1, failures_count
        assert_equal 1, $invokes
      end

      it "records failure if retry disabled and configured to track exhaustion" do
        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'retry' => false, 'failures' => 'exhausted')

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end
 
        assert_equal 1, failures_count
        assert_equal 1, $invokes
       end
 
      it "records failure if retry disabled and configured to track exhaustion by default" do
        Sidekiq.failures_default_mode = 'exhausted'

        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'retry' => false)

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 1, failures_count
        assert_equal 1, $invokes
      end

      it "records failure if failing last retry and configured to track exhaustion by default" do
        Sidekiq.failures_default_mode = 'exhausted'

        msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'], 'retry' => true, 'retry_count' => 24)

        assert_equal 0, failures_count

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [@processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { @boss.expect(:async, actor, []) }

        assert_raises TestException do
          @processor.process(msg)
        end

        assert_equal 1, failures_count
        assert_equal 1, $invokes
      end

      # TESTS FOR MANAGER

      it 'should update active jobs' do
        assert_equal 0, unique_jobs_count
        
        [MockWorker, MockWorker, MockWorker1, MockWorker2].each do |worker|
          processor = mock_actor
          msg = create_work('class' => worker.to_s, 'args' => ['myarg', 'success'])
          processor.process(msg)
        end

        assert_equal 3, unique_jobs_count
      end

      it 'should update job details' do
        assert_equal 0, job_details(MockWorker.to_s).length
        
        2.times do
          processor = mock_actor
          msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg', 'success'])
          processor.process(msg)
        end

        assert_equal 2, job_details(MockWorker.to_s).length
      end

      it 'should update both success and failed runs' do
        assert_equal 0, job_details(MockWorker.to_s).length

        2.times do
          processor = mock_actor
          msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg', 'success'])
          processor.process(msg)
        end

        3.times do
          processor = mock_actor
          msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg'])

          assert_raises TestException do
            processor.process(msg)
          end
        end

        details = job_details(MockWorker.to_s)

        assert_equal 3, details.select{|j| j['error']}.length
        assert_equal 2, details.select{|j| !j['error']}.length
      end

      it "removes old details when job_details_max_count has been reached" do
        assert_equal 1000, Sidekiq.job_details_max_count
        Sidekiq.job_details_max_count = 2

        5.times do
          processor = mock_actor
          msg = create_work('class' => MockWorker.to_s, 'args' => ['myarg', 'success'])
          processor.process(msg)
        end

        assert_equal 2, job_details(MockWorker.to_s).length
      end

      def failures_count
        Sidekiq.redis { |conn|conn.llen('failed') } || 0
      end

      def create_work(msg)
        Sidekiq::BasicFetch::UnitOfWork.new('default', Sidekiq.dump_json(msg))
      end

      def unique_jobs_count
        Sidekiq.redis { |conn|conn.zcard('unique_jobs') } || 0
      end

      def job_details job_name
        Sidekiq.redis { |conn|conn.lrange("#{job_name}:details", 0, 100).map{|j| Sidekiq.load_json(j)} }
      end

      def mock_actor
        boss = MiniTest::Mock.new
        processor = ::Sidekiq::Processor.new(boss)

        actor = MiniTest::Mock.new
        actor.expect(:processor_done, nil, [processor])
        actor.expect(:real_thread, nil, [nil, Celluloid::Thread])
        2.times { boss.expect(:async, actor, []) }        

        return processor
      end
    end
  end
end
