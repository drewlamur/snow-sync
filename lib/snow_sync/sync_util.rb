module SnowSync

  class SyncUtil

    require "base64"
    require "facets"
    require "fileutils"
    require "json"
    require "libnotify" if `uname` =~ /Linux/
    require 'rest-client'
    require "terminal-notifier-guard"
    require "yaml"

    attr_accessor :cf, :configs, :logger

    # Creates a utility object & sets the encapsulated config data
    # @param [String] opts Optional configuration

    def initialize(opts = nil)
      opts.nil? ? @cf = "configs.yml" : @cf = "test_configs.yml"
      @configs = YAML::load_file(@cf)
      @logger = Logger.new(STDERR)
    end

    # Creates a directory if no directory exists
    # @param [String] name Required directory name
    # @param [Object] &block Optional directory path

    def create_directory(name, &block)
      yield block if block_given?
      unless File.directory?(name)
        FileUtils.mkdir_p(name)
        @logger.info "++: #{name}"
      end
    end

    # Creates a subdirectory if no directory exists
    # @param [String] name Required directory name
    # @param [Object] &block Optional directory path

    def create_subdirectory(name, &block)
      create_directory(name, &block)
    end

    # Creates a JS file & logs the file creation
    # @param [String] name Required file name
    # @param [Object] json Required json object
    # @param [Object] &block Optional file path

    def create_file(name, json, &block)
      yield if block_given?
      File.open("#{name}.js", "w") do |f| 
        f.write(json)
        @logger.info "->: #{name}" + ".js"
      end
    end

    # Checks required configurations
    # @raise [ExceptionClass] Raises exception if configs are not found

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

    # Encrypts config credentials based on previous sync

    def encrypt_credentials
      unless @configs["creds"]["encrypted"]
        configs_path = @configs["conf_path"] + @cf
        configs = YAML::load_file(configs_path)
        # local configuration changes
        userb64 = Base64.strict_encode64(@configs["creds"]["user"])
        passb64 = Base64.strict_encode64(@configs["creds"]["pass"])
        configs["creds"]["user"] = userb64
        configs["creds"]["pass"] = passb64
        configs["creds"]["encrypted"] = true
        File.open(configs_path, 'w') { |f| YAML::dump(configs, f) }
        # object state configuration changes
        @configs["creds"]["user"] = userb64
	@configs["creds"]["pass"] = passb64
        @configs["creds"]["encrypted"] = true
      end
    end

    # Creates the dir structure, requests, retrieves & sets up JS files locally
    
    def run_setup_and_sync
      # sync directory boolean tracks sync dir creation
      # necessary for iterative subdir creation and re-syncs
      sync_directory = File.directory?("sync")
      directory_name = "sync"
      @configs["table_map"].each do |key, value|
        subdirectory_name = key
        if sync_directory
          path = proc { FileUtils.cd(directory_name) }
          create_subdirectory(subdirectory_name, &path)
        else
          create_directory(directory_name)
          path = proc { FileUtils.cd(directory_name) }
          create_subdirectory(subdirectory_name, &path)
          sync_directory = "true"
        end
        begin
          user = Base64.strict_decode64(@configs["creds"]["user"])
          pass = Base64.strict_decode64(@configs["creds"]["pass"])
          response = RestClient.get(
          "#{@configs['base_url']}#{value["table"]}?sysparm_query=sys_id%3D" + 
          "#{value["sys_id"]}%5Ename%3D#{value["name"]}",
            {:authorization => "#{"Basic " + Base64.strict_encode64("#{user}:#{pass}")}",
             :accept => "application/json"})
          path = proc { FileUtils.cd(subdirectory_name) }
          @configs["table_map"][key]["response"] = JSON.parse(response)["result"][0]
          json = JSON.parse(response)["result"][0][value["field"]]
          name = value["name"].snakecase
          create_file(name, json, &path)
          FileUtils.cd("../..")
        rescue => e
          @logger.error "ERROR: #{e}"
        end
      end
    end

    # Classifies a JS file by name
    # @param [String] file JS file by name
    # @return classified JS file by name

    def classify(file)
      file = file.split(".").first.camelcase
      file[0] = file[0].capitalize
      file
    end

    # Lookup returns the configured servicenow table hash
    # @param [String] type Config table label
    # @param [String] file JS file by name
    # @return configured servicenow table hash

    def table_lookup(type, file)
      @configs["table_map"].select do |key, value|
        if key.eql?(type) and value["name"].eql?(classify(file))
          return value
        end
      end
    end

    # Merges JS file changes with the encapsulated table response value
    # @param [String] type Config table label
    # @param [String] file JS file by name

    def merge_update(type, file)
      FileUtils.cd("sync" + "/" + type)
      script_body = File.open(file).read
      @configs["table_map"][type]["mod"] = script_body
      FileUtils.cd("../..")
    end

    # Completes a sync based on the configurations

    def start_sync
      check_required_configs
      encrypt_credentials
      run_setup_and_sync
    end

    # Merges all JS file changes & pushes to the configured servicenow instance
    # @param [Array] paths JS file paths

    def push_modifications(paths)
      paths.each do |path|
        path.downcase!
        path = path.split("/")
        type = path[1]
        file = path[2]
        table_hash = table_lookup(type, file)
        merge_update(type, file)
        begin
          user = Base64.strict_decode64(@configs["creds"]["user"])
          pass = Base64.strict_decode64(@configs["creds"]["pass"])
          request_body_map = { 
            table_hash["field"].to_sym => @configs["table_map"][type]["mod"]
          }
          response = RestClient.patch("#{@configs['base_url']}#{table_hash["table"]}/#{table_hash["sys_id"]}", 
          request_body_map.to_json,
            {:authorization => "#{"Basic " + Base64.strict_encode64("#{user}:#{pass}")}",
             :content_type => "application/json", :accept => "application/json"})
        rescue => e
          @logger.error "ERROR: #{e}"
        end
      end
    end

    # Dispatches osx & linux platform notification when file updates are pushed
    # @param [Array] update File updated
    # @param [Object] log Log object

    def notify(update, log)
      if `uname` =~ /Darwin/
        TerminalNotifier::Guard.success(
          "File: #{update * ','}",
          :title => "ServiceNow Script Update"
        )
        log.info "->: osx notification dispatched"
      elsif `uname` =~ /Linux/
        Libnotify.show(
          :summary => "ServiceNow Script Update",
          :body => "File: #{update * ','}",
          :timeout => 1.5
        )
        log.info "->: linux notification dispatched"
      end
    end

  end

end
