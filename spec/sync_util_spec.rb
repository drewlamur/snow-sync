require "spec_helper"

## --> unit tests
describe "utility object" do

  let! :util do
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

describe "create_directory" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  let! :created_time do 
    util.create_directory("sync")
    return File.ctime("sync")
  end

  it "should create a directory" do
    dir = `ls`.split("\n")
    expect(dir.include?("sync")).to eq true
  end

  it "should not create directory" do
    util.create_directory("sync")
    check_created_time = File.ctime("sync")
    expect(created_time).to eq check_created_time
  end

end

describe "create_file" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should create a file" do
    FileUtils.mkdir_p("sync")
    FileUtils.mkdir_p("sync/test_sub_dir")
    json = { "property" => "value" }
    name = "TestClass".snakecase
    path = proc do
      FileUtils.cd("sync/test_sub_dir")
    end
    util.create_file(name, json, &path)
    expect(File.exists?("test_class.js")).to eq true
    FileUtils.cd("../..")
    FileUtils.rm_rf("sync")
  end

end

describe "check_required_configs" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should raise an exception when there is no config path" do
    util.configs["conf_path"] = nil
    expect{util.check_required_configs}.to raise_error(/Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there is no base url" do
    util.configs["base_url"] = nil
    expect{util.check_required_configs}.to raise_error(/Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there is no username" do
    util.configs["creds"]["user"] = nil
    expect{util.check_required_configs}.to raise_error(/Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there is no password" do
    util.configs["creds"]["pass"] = nil
    expect{util.check_required_configs}.to raise_error(/Check the configuration path, base url, credentials or table to sync/)
  end

  it "should raise an exception when there are no tables mapped" do
    tables = util.configs["table_map"].keys
    tables.each do |table|
      util.configs["table_map"][table]["table"] = nil
      expect{util.check_required_configs}.to raise_error(/Check the configuration path, base url, credentials or table to sync/)
    end
  end

end

describe "classify" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should convert snake_case string to CamelCase" do
    js_file_path = "sync/script_include/test_class.js"
    cc = util.classify(js_file_path)
    expect(cc).to eq "TestClass"
  end

end

describe "table_lookup" do

  let :util do
    SnowSync::SyncUtil.new(opts = "test")
  end 

  it "should return configured SN table" do
    table_map = util.table_lookup("sync/script_include/test_class.js")
    expect(table_map.keys).to eq ["name", "table", "sys_id", "field"]
    expect(table_map["table"]).to eq "sys_script_include"
  end

end

describe "merge_update" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should merge script with the configs object" do
    FileUtils.mkdir_p("sync")
    FileUtils.mkdir_p("sync/test_sub_dir")
    json_resp = "var test = 'test'; \n" +
    "var testing = function(arg) { \n\tgs.print(arg) \n}; \n" +
    "testing('test');"
    name = "TestClass".snakecase
    path = proc do
      FileUtils.cd("sync/test_sub_dir")
    end
    util.create_file(name, json_resp, &path)
    FileUtils.cd("../..")
    file = "sync/test_sub_dir/test_class.js"
    table_map = util.table_lookup(file)
    util.merge_update(file, "script_include", table_map)
    expect(util.configs["table_map"]["script_include"]["mod"] != nil).to eq true
  end

end

## --> integration tests
describe "setup_sync_directories" do
 
  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should setup and synchronize field from the SN instance" do
    util.setup_sync_directories
    file = File.open("sync/script_include/test_class.js")
    expect(file.is_a?(Object)).to eq true
    FileUtils.rm_rf("sync")
  end
 
end

describe "push_modifications" do

  let! :util do
    SnowSync::SyncUtil.new(opts = "test")
  end

  it "should push modifications to a configured instance" do
    util.setup_sync_directories
    file = File.open("sync/script_include/test_class.js", "r+")
    lines = file.readlines
    file.close
    lines[0] = "// test comment -\n"
    newfile = File.new("sync/script_include/test_class.js", "w")
    lines.each do |line|
      newfile.write(line)
    end
    newfile.close
    util.push_modifications(["sync/script_include/test_class.js"])
    util.setup_sync_directories
    file = File.open("sync/script_include/test_class.js", "r+")
    lines = file.readlines
    file.close
    expect(lines[0]).to eq "// test comment -\n"
  end

end
