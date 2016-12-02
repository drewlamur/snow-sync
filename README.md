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
touch Gemfile
vim Gemfile
```

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

bundle install
```

```bash
cd /lib/snow_sync
vim configs.yml
```

Add your configs -- be sure to append /api/now/table/ to the base_url

```bash
guard -i
```

## Running the Tests

```bash
cd <path>/gems/snow_sync-<version>
touch test_configs.yml
vim /spec/sync_util_spec.rb
```
Add a test record to your instance (ex: script include) & update the test configs in spec/sync_util_spec.rb

```ruby
rspec spec/sync_util_spec.rb
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
