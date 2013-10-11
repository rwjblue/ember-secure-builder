require 'securerandom'
require 'spec_helper'

module EmberSecureBuilder
  describe CrossBrowserTestBatch do

    let(:batch) { CrossBrowserTestBatch.new options }
    let(:options)  do
      {
        :url   => url,
        :name  => name,
        :build => build,
        :tags  => tags,
        :redis => mock_redis,
        :platforms    => platforms,
        :results_path => results_path,
        :worker_class => mock_worker
      }
    end

    let(:mock_redis)   { Minitest::Mock.new }
    let(:mock_worker)  { Minitest::Mock.new }
    let(:url)          { "https://blahblah.com/something/#{SecureRandom.urlsafe_base64}" }
    let(:results_path) { SecureRandom.urlsafe_base64 }
    let(:job_name)     { SecureRandom.urlsafe_base64 }
    let(:platforms)    { [{browser: 'googlechrome', platform: 'Windows 7'},
                          {browser: 'firefox', platform: 'Windows 7', version: 24}] }
    let(:build)        { SecureRandom.urlsafe_base64 }
    let(:tags)         { [] }

    before do
      #def mock_redis.multi; [yield] * 2 if block_given?; end
      #def mock_redis.set(*); true; end
      #def mock_redis.sadd(*); true; end
      #def mock_redis.srem(*); true; end
      #def mock_redis.get(*); nil; end
      #def mock_redis.del(*); nil; end
      #def mock_redis.incrby(*); nil; end
      #def mock_redis.setex(*); true; end
      #def mock_redis.expire(*); true; end
      #def mock_redis.watch(*); true; end
      #def mock_redis.with_connection; yield self; end
      #def mock_redis.with; yield self; end
      #def mock_redis.exec; true; end
    end

    it "sets up attributes on init" do
      assert_equal build, batch.build
      assert_equal url, batch.url
      assert_equal name, batch.name
      assert_equal tags, batch.tags
      assert_equal results_path, batch.results_path
      assert_equal platforms, batch.platforms
    end

    describe "#register_batch" do
      it "adds the current build to the 'cross_browser_test_batch' set" do
        mock_redis.expect :sadd, 1, ['cross_browser_test_batch', build]

        batch.register_batch

        mock_redis.verify
      end
    end

    describe "#queue_all" do
      it "calls queue for each platform" do
        def batch.queue(platform); @queued_platforms ||= []; @queued_platforms << platform; end
        def batch.queued_platforms; @queued_platforms; end

        batch.queue_all

        assert_equal platforms, batch.queued_platforms
      end
    end

    describe "#queue" do
      let(:platform) { platforms.first }

      it "registers a job with the generated job_id" do
        def mock_worker.perform_async(*); end

        def batch.generate_job_id; 'hey hey boo boo'; end
        mock_redis.expect :sadd, 1, ["cross_browser_test_batch:#{build}", "hey hey boo boo"]

        batch.queue(platform)

        mock_redis.verify
      end

      it "creates a job_id for the provided platform" do
        def mock_redis.sadd(*); end
        def mock_worker.perform_async(*); end

        def batch.generate_job_id; @generate_job_id_called = true; end
        def batch.generate_job_id_called; @generate_job_id_called; end

        batch.queue(platforms.first)

        assert batch.generate_job_id_called
      end

      it "queues the job" do
        def mock_redis.sadd(*); end
        def batch.generate_job_id; 'hey hey boo boo'; end

        expected_options = { build: build,
                             url: url,
                             name: name,
                             tags: tags,
                             results_path: results_path,
                             job_id: 'hey hey boo boo' }.merge(platform)

        mock_worker.expect :perform_async, nil, [expected_options]

        batch.queue(platform)

        mock_redis.verify
      end
    end
  end
end