require "spec_helper"

describe "utility object" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should instantiate a utility object" do
    expect(util.is_a?(Object)).to eq true
  end
  
  it "should encapsulate a configs hash" do
    expect(util.configs.is_a?(Hash)).to eq true
  end

  it "should encapsulate a logger object" do
    expect(util.logger.is_a?(Object)).to eq true
  end

end

describe "#create_directory" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should create a directory" do
    util.create_directory("sync")
    dir = `ls`.split("\n")
    expect(dir.include?("sync")).to eq true
  end

  let :created_time do
    File.ctime("sync")
  end

  it "should not create directory" do
    util.create_directory("sync")
    check_created_time = File.ctime("sync")
    expect(created_time).to eq check_created_time
  end

end

describe "#create_file" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do 
    FileUtils.mkdir_p("sync/test_sub_dir")
  end

  after do
    FileUtils.cd("../..")
    FileUtils.rm_rf("sync")
  end

  it "should create a file" do
    json = { "property" => "value" }
    name = "TestClass".snakecase
    path = proc do
      FileUtils.cd("sync/test_sub_dir")
    end
    util.create_file(name, json, &path)
    expect(File.exists?("test_class.js")).to eq true
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

describe "#classify" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should convert snake_case string to CamelCase" do
    js_file_path = "sync/script_include/test_class.js"
    path = js_file_path.split("/")
    cc = util.classify(path[2])
    expect(cc).to eq "TestClass"
  end

end

describe "#table_lookup" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end 

  it "should return configured SN table" do
    table_map = util.table_lookup("script_include", "test_class.js")
    expect(table_map.keys).to eq ["name", "table", "sys_id", "field"]
    expect(table_map["table"]).to eq "sys_script_include"
  end

end

describe "#merge_update" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do
    FileUtils.mkdir_p("sync/script_include") 
  end

  after do
    FileUtils.rm_rf("sync")
  end

  it "should merge script with the configs object" do
    json_resp = "var test = 'test'; \n" +
    "var testing = function(arg) { \n\tgs.print(arg) \n}; \n" +
    "testing('test');"
    name = "TestClass".snakecase
    path = proc do
      FileUtils.cd("sync/script_include")
    end
    util.create_file(name, json_resp, &path)
    FileUtils.cd("../..")
    file = "sync/script_include/test_class.js"
    path = file.split("/")
    type = path[1]
    file = path[2]
    util.merge_update(type, file)
    expect(util.configs["table_map"]["script_include"]["mod"] != nil).to eq true
  end

end

describe "#run_setup_and_sync" do
 
  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do
    util.encrypt_credentials
  end

  after do
    FileUtils.rm_rf("sync")
  end

  it "should setup file locally and sync code from the instance" do
    util.run_setup_and_sync
    file = File.open("sync/script_include/test_class.js")
    expect(file.is_a?(Object)).to eq true
  end
 
end

describe "push_modifications - single table configuration" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do
    util.encrypt_credentials
  end
 
  after do
    FileUtils.rm_rf("sync")
  end

  it "should push modifications to a configured instance" do
    util.run_setup_and_sync
    file = File.open("sync/script_include/test_class.js", "r+")
    lines = file.readlines
    file.close
    lines[0] = "// test comment - single push \n"
    newfile = File.new("sync/script_include/test_class.js", "w")
    lines.each do |line|
      newfile.write(line)
    end
    newfile.close
    util.push_modifications(["sync/script_include/test_class.js"])
    # resync confirms mods were pushed to the instance
    util.run_setup_and_sync
    file = File.open("sync/script_include/test_class.js", "r+")
    lines = file.readlines
    file.close
    expect(lines[0]).to eq "// test comment - single push \n"
  end

end

describe "push_modifications - mutli-table configuration" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  before do
    util.encrypt_credentials
  end
       
  after do
    FileUtils.rm_rf("sync")
  end

  it "should push modifications to a configured instance" do
    def do_edit(file, edit)
      file = File.open(file, "r+")
      lines = file.readlines
      file.close  
      lines[0] = edit
      newfile = File.new(file, "w")
      lines.each do |line|
        newfile.write(line)
      end
      newfile.close
    end
    def run_check(file, edit)
      file = File.open(file, "r+")
      lines = file.readlines
      file.close
      expect(lines[0]).to eq edit
    end
    util.run_setup_and_sync
    # sys_script_include
    do_edit(
      "sync/script_include/test_class.js", "// test comment - multi push 1\n")
    # sys_ui_action
    do_edit(
      "sync/ui_action/test_action.js", "// test comment - multi push 2\n")
    # queued mods, push in sequence
    util.push_modifications(
      ["sync/script_include/test_class.js", "sync/ui_action/test_action.js"])
    # resync confirms mods were pushed to the instance
    util.run_setup_and_sync
    run_check("sync/script_include/test_class.js", "// test comment - multi push 1\n")
    run_check("sync/ui_action/test_action.js", "// test comment - multi push 2\n")
  end

end
