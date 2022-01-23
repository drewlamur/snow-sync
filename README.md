# SnowSync

[![Gem Version](https://img.shields.io/badge/gem-v3.1.5-brightgreen.svg)](https://rubygems.org/gems/snow_sync) [![Dependency Status](https://img.shields.io/badge/dependencies-up--to--date-blue.svg)](https://rubygems.org/gems/snow_sync) [![Downloads](https://img.shields.io/badge/downloads-25k%2B-lightgrey.svg)](https://rubygems.org/gems/snow_sync)

SnowSync is a file sync utility tool and API which provides a bridge for off platform ServiceNow development using an IDE or text editor locally.

SnowSync syncronizes configured fields (scripts) for a ServiceNow instance locally, then watches for file changes and syncs back changes to the corresponding record.

## Installation

```bash
mkdir snow-sync
```

```bash
cd snow-sync
```

```ruby
gem install --install-dir <path-to-the-snow-sync-dir> snow_sync
```

## Setup & Usage

```ruby
gem install bundler
```

```bash
cd <path-to-the-snow_sync-dir>/gems/snow_sync-<version>
```

OSX users run the following command:

```bash
brew install terminal-notifier
```

Create a Gemfile and add the following Gem dependencies:

```ruby
source "https://rubygems.org"
gem "facets", "~> 3.1.0"
gem "guard", "~> 2.14.0"
gem "guard-yield", "~> 0.1.0"
gem "json", "~> 2.6.1"
gem "libnotify", "~> 0.9.2"
gem "rake", "~> 13.0.6"
gem "rest-client", "~> 2.0.0"
gem "rspec", "~> 3.10.0"
gem "rspec-core", "~> 3.10.1"
gem "terminal-notifier-guard", "~> 1.7"
gem "thor", "0.19.1"
```

```bash
bundle install
```

```bash
cd /lib/snow_sync
```

* Setup the configurations in the configs.yml
* Supports multi-table map configurations
* YAML configuration path is the current working directory
* Append /api/now/table/ to the base_url

```bash
bundle exec guard -i
```

**Note:** if the sync directory is deleted after a successful sync, reset the credential configs in the configs.yml so they can be re-encrypted on the next sync


## Running the Tests

```bash
cd <path-to-the-snow-sync-dir>/gems/snow_sync-<version>
```

* Integration tests use a test record in the test instance
* Setup the test configurations in the test_configs.yml
* YAML configuration path is the current working directory
* Append /api/now/table/ to the base_url

```ruby
bundle exec rspec spec/sync_util_spec.rb
```

* Unit tests are pure, so they're not externally dependent

```ruby
bundle exec rspec spec/sync_util_mock_spec.rb
```

**Note:** if the sync directory is deleted after a successful sync, reset the credential configs in the test_configs.yml so they can be re-encrypted on the next sync

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
