require "spec_helper"

describe "#initialize" do

  before do
    allow(YAML).to receive(:load_file)
    allow(Logger).to receive(:new)
  end

  it "should construct an instance" do
    SnowSync::SyncUtil.new(opts = "test")
    expect(YAML).to have_received(:load_file).with("test_configs.yml")
    expect(Logger).to have_received(:new).with(STDERR)
  end 

end

describe "#create_directory" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let :logger do
    instance_double(Logger)
  end

  let :dir_name do
    "sync"
  end

  before do
    allow(File).to receive(:directory?).and_return(false)
    allow(FileUtils).to receive(:mkdir_p)
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:info)
  end

  it "should create a directory" do
    util.create_directory(dir_name)
    expect(File).to have_received(:directory?).with(dir_name)
    expect(FileUtils).to have_received(:mkdir_p).with(dir_name)
    expect(logger).to have_received(:info).with("++: #{dir_name}")
  end

end

describe "#create_subdirectory" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let :path do
    proc { FileUtils.cd("sync") }
  end

  let :sub_dir_name do
    "sub-dir-of-sync"
  end

  before do
    allow_any_instance_of(SnowSync::SyncUtil).to receive(:create_directory)
      .and_return("++: #{sub_dir_name}")
  end

  it "should create a subdirectory" do
    expect(util.create_subdirectory(sub_dir_name, &path)).to eq("++: #{sub_dir_name}")
  end

end

describe "#create_file" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let :logger do
    instance_double(Logger)
  end

  let :file_name do
    "test_file"
  end

  let :json do
    { "test-json": "testing" }
  end

  let :path do
    proc { }
  end

  before do
    allow(File).to receive(:open).and_call_original
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:info)
  end

  after do
    test_file = `ls`.split("\n").pop
    FileUtils.rm_rf(test_file)
  end

  it "should create a js file" do
    util.create_file(file_name, json, &path)
    expect(File).to have_received(:open).with(file_name + ".js", "w")
    expect(logger).to have_received(:info).with("->: #{file_name}" + ".js")
    expect(`ls`.split("\n").pop).to eq("test_file.js")
    expect(File.open("#{file_name}.js").read).to eq("{:\"test-json\"=>\"testing\"}")
  end

end

describe "#check_required_configs" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should raise an exception when there is no config path" do
    util.configs["conf_path"] = nil
    expect{util.check_required_configs}.to raise_error(
      /Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there is no base url" do
    util.configs["base_url"] = nil
    expect{util.check_required_configs}.to raise_error(
      /Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there is no username" do
    util.configs["creds"]["user"] = nil
    expect{util.check_required_configs}.to raise_error(
      /Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there is no password" do
    util.configs["creds"]["pass"] = nil
    expect{util.check_required_configs}.to raise_error(
      /Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there are no tables mapped" do
    tables = util.configs["table_map"].keys
    tables.each do |table|
      util.configs["table_map"][table]["table"] = nil
      expect{util.check_required_configs}.to raise_error(
        /Check the configuration path, base url, credentials or table to sync/)
    end
  end

end

describe "#encrypt_credentials" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end
 
  before do
    FileUtils.touch("spec/test_configs.yml")
    local_configs = {
      "conf_path" => "spec/",
      "base_url" => nil,
      "creds" => {
        "user" => "test-name",
        "pass" => "test-password",
        "encrypted" => false
      }
    }  
    allow(YAML).to receive(:load_file).and_return(local_configs)
    allow(Base64).to receive(:strict_encode64).and_call_original
    allow(File).to receive(:open).and_call_original
  end

  after do
    FileUtils.rm_rf("spec/test_configs.yml")
  end

  it "should encrypt credentials" do
    util.configs["conf_path"] = "spec/"
    util.configs["creds"]["user"] = "test-name"
    util.configs["creds"]["pass"] = "test-password"
    util.encrypt_credentials
    expect(YAML).to have_received(:load_file).with("spec/test_configs.yml")
    allow(Base64).to receive(:strict_encode64).twice
    expect(File).to have_received(:open).with("spec/test_configs.yml", "w")
    # configs object state updates
    expect(util.configs["creds"]["user"]).to eq("dGVzdC1uYW1l")
    expect(util.configs["creds"]["pass"]).to eq("dGVzdC1wYXNzd29yZA==")
    expect(util.configs["creds"]["encrypted"]).to eq(true)
    # test configs file updates
    encrypted_content = YAML::load_file("spec/test_configs.yml")
    expect(encrypted_content["creds"]["user"]).to eq("dGVzdC1uYW1l")
    expect(encrypted_content["creds"]["pass"]).to eq("dGVzdC1wYXNzd29yZA==")
    expect(encrypted_content["creds"]["encrypted"]).to eq(true)
  end
end

describe "#run_setup_and_sync" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let :logger do
    instance_double(Logger)
  end

  before do
    allow(Base64).to receive(:strict_decode64).and_call_original
    allow(Base64).to receive(:strict_encode64).and_call_original
    allow(RestClient).to receive(:get).and_return("{\"result\":[{ \"status\": \"200\" }]}")
    allow(FileUtils).to receive(:cd)
  end

  it "should run setup & sync - sync directory present path" do
    # allow not included in 'before' setup to set return bool
    allow(File).to receive(:directory?).and_return(true)
    expect_any_instance_of(SnowSync::SyncUtil).to receive(:create_subdirectory)
    expect_any_instance_of(SnowSync::SyncUtil).to receive(:create_file)
    util.configs = { "conf_path" => nil, 
      "base_url" => "https://test.com/api/now/table/",
      "creds" => {
        "user" => "dGVzdC1uYW1l", 
        "pass" => "dGVzdC1wYXNzd29yZA=="
      },
      "table_map" => {
        "script_include" => {
          "name" => "TestClass",
          "table" => "sys_script_include", 
          "sys_id" => "xxxxxx-sysid-xxxxxx",
          "field" => "test-field"
        }
      }
    }  
    util.run_setup_and_sync
    expect(File).to have_received(:directory?).with("sync")
    expect(Base64).to have_received(:strict_decode64).with("dGVzdC1uYW1l")
    expect(Base64).to have_received(:strict_decode64).with("dGVzdC1wYXNzd29yZA==")
    expect(Base64).to have_received(:strict_encode64).with("test-name:test-password")
    expect(RestClient).to have_received(:get).with(
      "https://test.com/api/now/table/sys_script_include?sysparm_query=sys_id%3D" +
      "xxxxxx-sysid-xxxxxx%5Ename%3DTestClass",
      {:authorization => "Basic " + "dGVzdC1uYW1lOnRlc3QtcGFzc3dvcmQ=",
       :accept => "application/json"})
    expect(FileUtils).to have_received(:cd).with("../..")
  end

  it "should run setup & sync - sync directory not present path" do
    # allow not included in 'before' setup to set return bool
    allow(File).to receive(:directory?).and_return(false)
    expect_any_instance_of(SnowSync::SyncUtil).to receive(:create_directory)
    expect_any_instance_of(SnowSync::SyncUtil).to receive(:create_subdirectory)
    expect_any_instance_of(SnowSync::SyncUtil).to receive(:create_file)
    util.configs = { "conf_path" => nil, 
      "base_url" => "https://test.com/api/now/table/",
      "creds" => {
        "user" => "dGVzdC1uYW1l", 
        "pass" => "dGVzdC1wYXNzd29yZA=="
      },
      "table_map" => {
        "script_include" => {
          "name" => "TestClass",
          "table" => "sys_script_include", 
          "sys_id" => "xxxxxx-sysid-xxxxxx",
          "field" => "test-field"
        }
      }
    } 
    util.run_setup_and_sync
    expect(File).to have_received(:directory?).with("sync")
    expect(Base64).to have_received(:strict_decode64).with("dGVzdC1uYW1l")
    expect(Base64).to have_received(:strict_decode64).with("dGVzdC1wYXNzd29yZA==")
    expect(Base64).to have_received(:strict_encode64).with("test-name:test-password")
    expect(RestClient).to have_received(:get).with(
      "https://test.com/api/now/table/sys_script_include?sysparm_query=sys_id%3D" +
      "xxxxxx-sysid-xxxxxx%5Ename%3DTestClass",
      {:authorization => "Basic " + "dGVzdC1uYW1lOnRlc3QtcGFzc3dvcmQ=",
       :accept => "application/json"})
    expect(FileUtils).to have_received(:cd).with("../..")
  end

  it "should handle an exception" do
    # allow not included in 'before' setup to set return bool
    allow(File).to receive(:directory?).and_return(true)
    expect_any_instance_of(SnowSync::SyncUtil).to receive(:create_subdirectory)
    allow(RestClient).to receive(:get).and_raise(RestClient::ExceptionWithResponse)
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:error)
    util.configs = { "conf_path" => nil, 
      "base_url" => "https://test.com/api/now/table/",
      "creds" => {
        "user" => "dGVzdC1uYW1l", 
        "pass" => "dGVzdC1wYXNzd29yZA=="
      },
      "table_map" => {
        "script_include" => {
          "name" => "TestClass",
          "table" => "sys_script_include", 
          "sys_id" => "xxxxxx-sysid-xxxxxx",
          "field" => "test-field"
        }
      }
    } 
    util.run_setup_and_sync
    expect(logger).to have_received(:error)
      .with("ERROR: RestClient::ExceptionWithResponse").once
  end

end

describe "#classify" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should convert snake_case string to CamelCase" do
    expect(util.classify("test_class.js")).to eq("TestClass")
  end

end

describe "#table_lookup" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end 

  it "should return configured SN table" do
    util.configs = { "conf_path" => nil, 
      "base_url" => "https://test.com/api/now/table/",
      "creds" => {
        "user" => "dGVzdC1uYW1l", 
        "pass" => "dGVzdC1wYXNzd29yZA=="
      },
      "table_map" => {
        "script_include" => {
          "name" => "TestClass",
          "table" => "sys_script_include", 
          "sys_id" => "xxxxxx-sysid-xxxxxx",
          "field" => "test-field"
        }
      }
    } 
    table_map = util.table_lookup("script_include", "test_class.js")
    expect(table_map == { "name" => "TestClass", 
      "table" => "sys_script_include", 
      "sys_id" => "xxxxxx-sysid-xxxxxx",
      "field" => "test-field"
    }).to be(true)
  end

end

describe "#merge_update" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do
    allow(FileUtils).to receive(:cd)
    allow(File).to receive(:open).and_return(IO)
    allow(IO).to receive(:read).and_return("var x = 10;")  
  end

  it "should merge a script change" do
    util.configs = { "table_map" => {
      "script_include" => {
        "name" => "TestClass",
        "table" => "sys_script_include", 
        "sys_id" => "xxxxxx-sysid-xxxxxx",
        "field" => "test-field"
        }
      }
    } 
    util.merge_update("script_include", "test_class.js")
    expect(File).to have_received(:open).with("test_class.js")
    expect(IO).to have_received(:read)
    expect(FileUtils).to have_received(:cd).twice
    expect(util.configs == { "table_map" => {
      "script_include" => {
        "name" => "TestClass", 
        "table" => "sys_script_include", 
        "sys_id" => "xxxxxx-sysid-xxxxxx", 
        "field" => "test-field", 
        "mod" => "var x = 10;"
      }
    }}).to be(true)
end

end

describe "#start_sync" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do
    allow_any_instance_of(SnowSync::SyncUtil).to receive(:check_required_configs)
    allow_any_instance_of(SnowSync::SyncUtil).to receive(:encrypt_credentials)
    allow_any_instance_of(SnowSync::SyncUtil).to receive(:run_setup_and_sync)
      .and_return("sync-and-setup-complete!")
  end

  it "should create a subdirectory" do
    expect(util.start_sync).to eq("sync-and-setup-complete!")
  end

end

describe "#push_modifications" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let :logger do
    instance_double(Logger)
  end

  before do
    allow_any_instance_of(SnowSync::SyncUtil).to receive(:table_lookup)
      .and_return({
        "name" => "TestClass",
        "table" => "sys_script_include",
        "sys_id" => "xxxxxx-sysid-xxxxxx",
        "field" => "test-field",
        "mod" => "var x = 10;"
       })
    allow_any_instance_of(SnowSync::SyncUtil).to receive(:merge_update)
    allow(Base64).to receive(:strict_decode64).and_call_original
    allow(Base64).to receive(:strict_encode64).and_call_original
    allow(RestClient).to receive(:patch).and_return("{\"result\":[{ \"status\": \"201\" }]}")
  end

  it "should push modifications to the instance" do
    util.configs = { "conf_path" => nil, 
      "base_url" => "https://test.com/api/now/table/",
      "creds" => {
        "user" => "dGVzdC1uYW1l", 
        "pass" => "dGVzdC1wYXNzd29yZA=="
      },
      "table_map" => {
        "script_include" => {
          "name" => "TestClass",
          "table" => "sys_script_include", 
          "sys_id" => "xxxxxx-sysid-xxxxxx",
          "field" => "test-field",
          "mod" => "var x = 10;"
        }
      }
    }
    util.push_modifications(["sync/script_include/test_class.js"]) 
    expect(Base64).to have_received(:strict_decode64).with("dGVzdC1uYW1l")
    expect(Base64).to have_received(:strict_decode64).with("dGVzdC1wYXNzd29yZA==")
    expect(Base64).to have_received(:strict_encode64).with("test-name:test-password")
    expect(RestClient).to have_received(:patch).with(
      "https://test.com/api/now/table/sys_script_include/xxxxxx-sysid-xxxxxx",
      "{\"test-field\":\"var x = 10;\"}",
      {:authorization => "Basic " + "dGVzdC1uYW1lOnRlc3QtcGFzc3dvcmQ=", 
       :content_type => "application/json", :accept => "application/json"})   
  end

  it "should handle an exception" do
    allow(RestClient).to receive(:patch).and_raise(RestClient::ExceptionWithResponse)
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:error)
    util.configs = { "conf_path" => nil,
      "base_url" => "https://test.com/api/now/table/",
      "creds" => {
        "user" => "dGVzdC1uYW1l",
        "pass" => "dGVzdC1wYXNzd29yZA=="
      },
      "table_map" => {
        "script_include" => {
          "name" => "TestClass",
          "table" => "sys_script_include",
          "sys_id" => "xxxxxx-sysid-xxxxxx",
          "field" => "test-field",
          "mod" => "var x = 10;"
        }
      }
    }
    util.push_modifications(["sync/script_include/test_class.js"])
    expect(logger).to have_received(:error)
      .with("ERROR: RestClient::ExceptionWithResponse").once
  end

end

describe "#notify" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let :logger do
    instance_double(Logger)
  end

  let :update do
    "test_class"
  end

  let :macosx? do
    `uname`.chomp.downcase == "darwin"
  end

  let :linux? do
    `uname`.chomp.downcase == "linux"
  end

  before do
    allow(TerminalNotifier::Guard).to receive(:success) if macosx?
    allow(Libnotify).to receive(:show) if linux?
    allow(Logger).to receive(:new).and_return(logger)
    allow(logger).to receive(:info)
  end

  condition = `uname`.chomp.downcase == "darwin"
  context "when true", if: condition do
    it "should send notification - macosx path" do
      uname = "darwin"
      util.notify(update, uname, util.logger)
      expect(TerminalNotifier::Guard).to have_received(:success)
        .with("File: #{update}", :title => "ServiceNow Script Update")
      expect(logger).to have_received(:info).with("->: osx notification dispatched") 
    end
  end

  condition = `uname`.chomp.downcase == "linux"
  context "when true", if: condition do
    it "should send notification - linux path" do
      uname = "linux"
      util.notify(update, uname, util.logger)
      expect(Libnotify).to have_received(:show)
        .with(:summary => "ServiceNow Script Update", :body => "File: #{update}")
      expect(logger).to have_received(:info).with("->: linux notification dispatched") 
    end
  end

end
