# SnowSync

SnowSync is a file sync utility tool and API which provides a bridge for off platform ServiceNow development using an IDE or text editor locally.

SnowSync syncronizes configured fields (scripts) for a ServiceNow instance locally, then watches for file changes and syncs back changes to the corresponding record.

## Installation

```ruby
gem install --install-dir <path> snow_sync
```

## Setup & Usage

```ruby
gem install bundler
```

```bash
cd <path>/gems/snow_sync-<version>
```

Create a Gemfile and add the following:

```ruby
source 'https://rubygems.org'
gem 'byebug', '~> 9.0.6'
gem 'facets', '~> 3.1.0'
gem 'guard', '~> 2.14.0'
gem 'guard-yield', '~> 0.1.0'
gem 'json', '>= 1.8.3', '~> 1.8.0'
gem 'libnotify', '~> 0.9.1'
gem 'rake', '~> 10.0.0'
gem 'rest-client', '~> 2.0.0'
gem 'rspec', '~> 3.5.0'
gem 'thor', '0.19.1'
```

```bash
bundle install
```

```bash
cd /lib/snow_sync
```

* Setup the configurations in the configs.yml
* Configuration path is the current working directory
* Append /api/now/table/ to the base_url

```bash
guard -i
```

Note: if the sync directory is deleted after a previous sync, reset the credential configs in the configs.yml so they can be re-encrypted


## Running the Tests

```bash
cd <path>/gems/snow_sync-<version>
```

* Create a test_configs.yml file
* Create a test record in the instance (ex: a test script include)
* Setup the test configurations in the test_configs.yml
* Configuration path is the current working directory
* Append /api/now/table/ to the base_url

```ruby
rspec spec/sync_util_spec.rb
```

Note: if the sync directory is deleted after a previous sync, reset the credential configs in the test_configs.yml so they can be re-encrypted

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
