require 'kaplan'
require 'rails'

module Kaplan
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.dirname(__FILE__) + "/tasks/kaplan.rake"
    end
  end
end