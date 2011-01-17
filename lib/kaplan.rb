require File.dirname(__FILE__) + '/kaplan/railtie' if defined?(Rails)

module Kaplan
  module DatabaseAdapters
    module ActiveRecord
      def database_settings
        @database_settings ||= ::YAML.load_file("#{project_root}/config/database.yml")
      end

      def establish_database(env = current_environment)
        ::ActiveRecord::Base.establish_connection(database_settings[env.to_s])
      end

      def all_collections
        ::ActiveRecord::Base.connection.tables - ["schema_migrations"]
      end

      def plow_collection(name)
        ::ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{::ActiveRecord::Base.connection.quote_table_name(name)}")
      end
    end

    module Mongoid
      def database_settings
        @database_settings ||= ::YAML.load_file("#{project_root}/config/database.mongo.yml")
      end

      def establish_database(env = current_environment)
        ::Mongoid.config.database = ::Mongo::Connection.new.db(database_settings[env.to_s]["database"])
      end

      def all_collections
        ::Mongoid.database.collection_names - ["system.indexes"]
      end

      def plow_collection(name)
        ::Mongoid.database.drop_collection(name)
      end
    end
  end

  module WebFrameworks
    module Rails
      def project_root
        ::Rails.root
      end

      def current_environment
        ::Rails.env.to_s
      end
      
      def current_environment=(environment)
        if ::Rails.version.split(".")[0] == "3"
          ::Rails.env = environment
        else
          silence_warnings do
            ::Rails.instance_variable_set("@_env", nil)
            Object.const_set(:RAILS_ENV, environment)
          end
        end
        puts "Current environment: #{current_environment}"
      end
    end

    module Padrino
      def project_root
        ::Padrino.root
      end

      def current_environment
        ::Padrino.env.to_s
      end
      
      def current_environment=(environment)
        silence_warnings do
          ::Padrino.instance_variable_set("@_env", nil)
          Object.const_set(:PADRINO_ENV, environment)
        end
      end
    end
  end

  class << self
    def choose_database_adapter
      if defined?(::ActiveRecord)
        Kaplan.extend(Kaplan::DatabaseAdapters::ActiveRecord)
      elsif defined?(::Mongoid)
        Kaplan.extend(Kaplan::DatabaseAdapters::Mongoid)
      end
    end

    def choose_web_framework
      if defined?(::Rails)
        Kaplan.extend(Kaplan::WebFrameworks::Rails)
      elsif defined?(::Padrino)
        Kaplan.extend(Kaplan::WebFrameworks::Padrino)
      end
    end

    def seeds(env)
      (Dir["#{project_root}/seeds/*.{yml,rb,txt,csv}"] + Dir["#{project_root}/seeds/#{env}/*.{yml,rb,txt,csv}"]).
      reject {|filename| File.directory?(filename) }.
      map do |filename|
        basename = ::File.basename(filename)
        basename =~ /^(.+?)\.([^.]+)$/
        collection_name = $1
        extension = $2.downcase
        model = collection_name.classify.constantize
        [filename, extension, collection_name, model]
      end
    end

    LEVELS = [:none, :info, :debug]

    def seed_database(options={})
      level = LEVELS.index(options[:level] || :debug)
      options.reverse_merge!(:env => current_environment)
      puts "Seeding the #{options[:env]} database..." if level > 0
      establish_database(options[:env])
      seeds(options[:env]).each do |filename, ext, collection_name, model|
        if ext == "rb"
          puts " - Adding data for #{collection_name}..." if level > 1
          load filename
        elsif ext == "yml" || ext == "yaml"
          data = ::YAML.load_file(filename)
          records = (Hash === data) ? data[data.keys.first] : data
          puts " - Adding data for #{collection_name}..." if level > 1
          insert_rows(records, model)
        else
          lines = ::File.read(filename).split(/\n/)
          puts " - Adding data for #{collection_name}..." if level > 1
          insert_rows_from_csv(lines, model)
        end
      end
    end

    def plow_database(options={})
      level = LEVELS.index(options[:level] || :debug)
      options.reverse_merge!(:env => current_environment)
      puts "Plowing the #{options[:env]} database..." if level > 0
      establish_database(options[:env])
      collections = options[:all] ? all_collections : seedable_collections(options[:env])
      collections.each do |coll|
        plow_collection(coll)
        puts " - Plowed #{coll}" if level > 1
      end
    end

    def seedable_collections(env)
      # Remove collections that don't exist
      seeds(env).map {|filename, ext, collection_name, model| collection_name } & all_collections
    end

  private
    def insert_rows(rows, model)
      rows.each do |row|
        record = model.new
        # set attributes explicitly instead of just shoving them into .new
        # in case 'id' is one of the attributes (which would get ignored otherwise)
        row.each {|k,v| record.send("#{k}=", v) }
        record.save!
      end
    end

    def insert_rows_from_csv(lines, model)
      columns = lines.shift.sub(/^#[ ]*/, "").split(/,[ ]*/)
      rows = lines.map do |line|
        values = line.split(/\t|[ ]{2,}/).map {|v| v =~ /^null$/i ? nil : v }
        zip = columns.zip(values).flatten
        Hash[*zip]
      end
      insert_rows(rows, model)
    end
  end
end

Kaplan.choose_database_adapter
Kaplan.choose_web_framework