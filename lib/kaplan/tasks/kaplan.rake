namespace :kaplan do
  namespace :db do
    desc "Resets a database of your choice by re-creating it from the development schema and then re-seeding it"
    task :reset, [:env] => :environment do |t, args|
      env = args[:env] || ENV["RAILS_ENV"]
      raise "Can't reset the dev database" if env == "development"
      #raise "No environment specified. Pass the environment to the task as an argument to specify the environment." unless env
      puts "Resetting #{env} database by cloning dev schema and seeding db..."
      Rake::Task['kaplan:db:clone_structure'].invoke(env)
      Rake::Task['kaplan:db:seed'].invoke(env)
    end

    desc "Seeds a database of your choice (default: development) with bootstrap data.\nThe relevant tables are truncated first so you don't have to."
    task :seed, [:env] => :environment do |t, args|
      env = args[:env] || ENV["RAILS_ENV"] || "development"
      #raise "No environment specified. Pass the environment to the task as an argument to specify the environment." unless env
      Rake::Task['kaplan:db:plow'].invoke(env)
      Kaplan.seed_database(:env => env)
      Kaplan.establish_database(env)
      Rake::Task['db:seed'].invoke
    end

    desc "Truncates tables in a database of your choice (default: development).\nBy default this just truncates the seed tables, if you want all of them pass ALL=true."
    task :plow, [:env] => :environment do |t, args|
      env = args[:env] || ENV["RAILS_ENV"] || "development"
      #raise "No environment specified. Pass the environment to the task as an argument to specify the environment." unless env
      all = !!ENV["ALL"]
      Kaplan.plow_database(:env => env, :all => all)
    end

    desc "Dumps the structure of the development database to file and copies it to the database of your choice.\nAdapters must be the same."
    task :clone_structure, [:env] => :environment do |t, args|
      env = args[:env] || ENV["RAILS_ENV"]
      raise "Can't clone the dev database to the dev database" if env == "development"
      #raise "No environment specified. Pass the environment to the task as an argument to specify the environment." unless env
      puts "Cloning dev structure to #{env} database..."

      abcs = ActiveRecord::Base.configurations
      adapter = abcs[env]["adapter"]
      development_adapter = abcs["development"]["adapter"]
      if adapter != development_adapter
        raise "Development db adapter and #{env} db adapter must be the same to clone"
      end

      Kaplan.current_environment = env
      Kaplan.establish_database
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke

      Kaplan.current_environment = 'development'
      Kaplan.establish_database
      Rake::Task["db:structure:dump"].invoke

      Kaplan.current_environment = env
      Kaplan.establish_database
      case adapter
      when "mysql"
        ActiveRecord::Base.establish_connection(env)
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
        IO.readlines("#{RAILS_ROOT}/db/development_structure.sql").join.split("\n\n").each do |table|
          ActiveRecord::Base.connection.execute(table)
        end
      when "postgresql"
        ENV['PGHOST']     = abcs[env]["host"] if abcs[env]["host"]
        ENV['PGPORT']     = abcs[env]["port"].to_s if abcs[env]["port"]
        ENV['PGPASSWORD'] = abcs[env]["password"].to_s if abcs[env]["password"]
        `psql -U "#{abcs[env]["username"]}" -f #{Rails.root}/db/development_structure.sql #{abcs[env]["database"]}`
      when "sqlite", "sqlite3"
        dbfile = abcs[env]["database"] || abcs[env]["dbfile"]
        `#{abcs[env]["adapter"]} #{dbfile} < #{RAILS_ROOT}/db/development_structure.sql`
      end
    end

    desc "Creates a database of your choice (default: development)"
    task :create, [:env] => :environment do |t, args|
      env = args[:env] || ENV["RAILS_ENV"] || "development"
      #raise "No environment specified. Pass the environment to the task as an argument to specify the environment." unless env
      puts "Creating #{env} database..."
      Kaplan.current_environment = env
      Kaplan.establish_database
      Rake::Task['db:create'].invoke
    end

    desc "Drops the database of your choice (default: development)"
    task :drop, [:env] => :environment do |t, args|
      env = args[:env] || ENV["RAILS_ENV"] || "development"
      #raise "No environment specified. Pass the environment to the task as an argument to specify the environment." unless env
      puts "Dropping #{env} database..."
      Kaplan.current_environment = env
      Kaplan.establish_database
      Rake::Task['db:drop'].invoke
    end
  end
end