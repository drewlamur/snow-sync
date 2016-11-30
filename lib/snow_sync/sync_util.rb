module SnowSync

  class SyncUtil

    require "base64"
    require "facets"
    require "fileutils"
    require "json"
    require 'rest-client'
    require "yaml"

    attr_accessor :configs, :logger

    def initialize(opts = nil)
      opts.nil? ? c = "configs.yml" : c = "test_configs.yml"
      @configs = YAML::load_file(c)
      @logger = Logger.new(STDERR)
    end
   
    def create_directory(name, &block)
      yield block if block_given?
      unless File.directory?(name)
        FileUtils.mkdir_p(name)
        @logger.info "++: #{name}"
      end
    end

    def create_file(name, json, &block)
      yield if block_given?
      File.open("#{name}.js", "w") do |f| 
        f.write(json)
        @logger.info "->: #{name}" + ".js"
      end
    end

    def check_required_configs
      no_credentials = @configs["creds"].values.any? do |e|
        e.nil?
      end
      keys = @configs["table_map"].keys
      keys.each do |key|
        no_table_map = @configs["table_map"][key].values.any? do |e|
          e.nil?
        end
          if no_credentials or no_table_map
            raise "EXCEPTION: Required configs missing in configs.yml. " \
            "Please check your credentials and tables to sync."
          else
            return @configs
          end
      end
    end

    def setup_sync_directories
      @configs["table_map"].each do |key, value|
        directory_name = "sync"
        create_directory(directory_name)
        path = proc { FileUtils.cd(directory_name) }
        sub_directory_name = key
        create_directory(sub_directory_name, &path)
        begin
          user = @configs["creds"]["user"]
          pass = @configs["creds"]["pass"]
          response = RestClient.get(
          "#{@configs['base_url']}#{value["table"]}?sysparm_query=sys_id%3D" + 
          "#{value["sysid"]}%5Ename%3D#{value["name"]}",
            {:authorization => "#{"Basic " + Base64.strict_encode64("#{user}:#{pass}")}", 
             :accept => "application/json"})
          path = proc { FileUtils.cd(sub_directory_name) }
          @configs[value["table"] + "_response"] = JSON.parse(response)["result"][0]
          json = JSON.parse(response)["result"][0][value["field"]]
          name = value["name"].snakecase
          create_file(name, json, &path)
          FileUtils.cd("../..")
        rescue => e
          @logger.error "ERROR: #{e}"
        end
      end
    end

    def classify(file)
      file = file.split("/").last.split(".").first.camelcase
      file[0] = file[0].capitalize
      return file
    end

    def table_lookup(file)
      @configs["table_map"].select do |key, value|
        if value["name"].eql?(classify(file))
          return value
        end
      end
    end

    def merge_update(file, table_hash)
      FileUtils.cd(file.split("/")[0..1].join("/"))
      script_body = File.open(file.split("/").last).read
      @configs[table_hash["table"] + "_response"] = script_body
      FileUtils.cd("../..")
    end

    def start_sync
      check_required_configs
      setup_sync_directories
    end

    def push_modifications(files)
      files.each do |file|
        file.downcase!
        table_hash = table_lookup(file)
        merge_update(file, table_hash)
        begin
          user = @configs["creds"]["user"]
          pass = @configs["creds"]["pass"]
          request_body_map = { 
            table_hash["field"].to_sym => @configs[table_hash["table"] + "_response"] 
          }
          response = RestClient.patch("#{@configs['base_url']}#{table_hash["table"]}/#{table_hash["sysid"]}", 
          request_body_map.to_json,
            {:authorization => "#{"Basic " + Base64.strict_encode64("#{user}:#{pass}")}",
             :content_type => "application/json", :accept => "application/json"})
        rescue => e
          @logger.error "ERROR: #{e}"
        end
      end
    end

  end

end
