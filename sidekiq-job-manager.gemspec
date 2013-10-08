# -*- encoding: utf-8 -*-
require File.expand_path('../lib/sidekiq/job-manager/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Leonid Bugaev"]
  gem.email         = ["leonsbox@gmail.com"]
  gem.description   = %q{Manage your sidekiq jobs}
  gem.summary       = %q{Keeps track of Sidekiq jobs and adds a tab to the Web UI to let you browse them.}
  gem.homepage      = "https://github.com/buger/sidekiq-job-manager/"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "sidekiq-job-manager"
  gem.require_paths = ["lib"]
  gem.version       = Sidekiq::JobManager::VERSION

  gem.add_dependency "sidekiq", ">= 2.9.0"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rack-test"
  gem.add_development_dependency "sprockets"
  gem.add_development_dependency "sinatra"
  gem.add_development_dependency "slim"
  gem.add_development_dependency "connection_pool"
  gem.add_development_dependency "mock_redis"
end
