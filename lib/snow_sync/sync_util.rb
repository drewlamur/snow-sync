module SnowSync

  class SyncUtil

    require "base64"
    require "facets"
    require "fileutils"
    require "json"
    require 'rest-client'
    require "yaml"

    attr_accessor :cf, :configs, :logger

    # creates a utility object
    # sets the encapsulated data
    # opts {string}: optional configuration

    def initialize(opts = nil)
      opts.nil? ? @cf = "configs.yml" : @cf = "test_configs.yml"
      @configs = YAML::load_file(@cf)
      @logger = Logger.new(STDERR)
    end

    # creates a directory if no directory exists
    # name {string}: required directory name
    # &block {object}: optional directory path

    def create_directory(name, &block)
      yield block if block_given?
      unless File.directory?(name)
        FileUtils.mkdir_p(name)
        @logger.info "++: #{name}"
      end
    end

    # creates a js file
    # logs the file creation
    # name {string}: required file name
    # json {object}: required json object
    # &block {object}: optional file path

    def create_file(name, json, &block)
      yield if block_given?
      File.open("#{name}.js", "w") do |f| 
        f.write(json)
        @logger.info "->: #{name}" + ".js"
      end
    end

    # checks required configurations
    # raises an exception when configs aren't found

    def check_required_configs
      missing_path = @configs["conf_path"].nil?
      missing_url = @configs["base_url"].nil?
      missing_creds = @configs["creds"].values.any? { |val| val.nil? }
      keys = @configs["table_map"].keys
      keys.each do |key|
        missing_map = @configs["table_map"][key].values.any? { |val| val.nil? }
        if missing_path or missing_url or missing_creds or missing_map
          raise "EXCEPTION: Required configs missing in configs.yml. " \
          "Check the configuration path, base url, credentials or table to sync."
        end
      end    
    end

    # encrypts config credentials based on previous sync

    def encrypt_credentials
      previous_sync = File.directory?("sync")
      if !previous_sync
        configs_path = @configs["conf_path"] + @cf
        configs = YAML::load_file(configs_path)
        # local configuration changes
        userb64 = Base64.strict_encode64(@configs["creds"]["user"])
        passb64 = Base64.strict_encode64(@configs["creds"]["pass"])
        configs["creds"]["user"] = userb64
        configs["creds"]["pass"] = passb64
        File.open(configs_path, 'w') { |f| YAML::dump(configs, f) }
        # object state configuration changes
        @configs["creds"]["user"] = userb64
	@configs["creds"]["pass"] = passb64
      end
    end

    # requests, retrieves, sets up the js script file locally
    
    def setup_sync_directories
      @configs["table_map"].each do |key, value|
        directory_name = "sync"
        create_directory(directory_name)
        path = proc { FileUtils.cd(directory_name) }
        sub_directory_name = key
        create_directory(sub_directory_name, &path)
        begin
          user = Base64.strict_decode64(@configs["creds"]["user"])
          pass = Base64.strict_decode64(@configs["creds"]["pass"])
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

    # classify's a local js file name
    # file {string}: js file path

    def classify(file)
      file = file.split("/").last.split(".").first.camelcase
      file[0] = file[0].capitalize
      file
    end

    # returns the configured SN table hash
    # file {string}: js file path 

    def table_lookup(file)
      @configs["table_map"].select do |key, value|
        if value["name"].eql?(classify(file))
          return value
        end
      end
    end

    # replaces the encapsulated table response value
    # with the current js file updates
    # file {string}: js file path
    # table_hash {hash}: configured SN table hash

    def merge_update(file, table_hash)
      FileUtils.cd(file.split("/")[0..1].join("/"))
      script_body = File.open(file.split("/").last).read
      @configs[table_hash["table"] + "_response"] = script_body
      FileUtils.cd("../..")
    end

    # check required configurations
    # encrypt configured credentials
    # retrieve, set up the script file locally

    def start_sync
      check_required_configs
      encrypt_credentials
      setup_sync_directories
    end

    # merges all js file changes
    # updates a SN instance with the changes
    # files {array}: array of js file paths

    def push_modifications(files)
      files.each do |file|
        file.downcase!
        table_hash = table_lookup(file)
        merge_update(file, table_hash)
        begin
          user = Base64.strict_decode64(@configs["creds"]["user"])
          pass = Base64.strict_decode64(@configs["creds"]["pass"])
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
