# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "kaplan/version"

Gem::Specification.new do |s|
  s.name        = "kaplan"
  s.version     = Kaplan::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Elliot Winkler"]
  s.email       = ["elliot.winkler@gmail.com"]
  s.homepage    = "http://rubygems.org/gems/kaplan"
  s.summary     = %q{Database- and framework-agnostic Rake tasks to prepare and seed your test database}
  s.description = %q{Kaplan provides some Rake tasks that are helpful in preparing your test database(s), such as seeding/plowing your database, or recreating it from your development database.}

  s.files         = ["README.md", "kaplan.gemspec"] + Dir["lib/**/*"]
  s.test_files    = Dir["{test,spec/features}/**/*"]
  s.executables   = Dir["bin/**/*"].map {|f| File.basename(f) }
  s.require_paths = ["lib"]
end
