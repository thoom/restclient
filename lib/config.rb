module Thoom
  class ConfigError < RuntimeError
    attr_reader :message

    def initialize(message)
      @message = message
    end
  end

  class ConfigFileError < ConfigError
  end

  module Config
    def config_set(config)
      @config = config.deep_symbolize_keys
    end

    def get(key, default_val = nil)
      key = key.to_sym
      if @config.key?(@env) && @config[@env].key?(key)
        @config[@env][key]
      elsif @config.key?(:default) && @config[:default].key?(key)
        @config[:default][key]
      elsif @config.key? key
        @config[key]
      elsif !default_val.nil?
        default_val
      else
        raise ConfigError, "Missing required configuration entry for #{key}"
      end
    end

    def env=(val)
      @env = val.to_sym
    end

    def set(key, val, env = :default)
      env = env.to_sym
      key = key.to_sym

      @config[env] = {} unless @config.key? env
      @config[env][key] = val
    end

    def print
      @config.to_s
    end
  end

  class HashConfig
    include Config

    def initialize(hash = {}, env = :default)
      @env = env
      config_set(hash)
    end
  end

  class YamlConfig
    require 'yaml'

    include Config

    def initialize(filename, env = :default)
      file = (File.exist? filename) ? filename : File.expand_path("~/#{filename}")
      raise ConfigFileError, "Configuration file #{filename} not found" unless File.exist? file

      yaml = YAML.load_file file
      raise ConfigFileError, "Configuration file #{file} is empty!" unless yaml

      @env = env
      config_set(yaml)
    end
  end
end

# pulled from https://raw.githubusercontent.com/rails/rails/f1bad130d0c9bd77c94e43b696adca56c46a66aa/activesupport/lib/active_support/core_ext/hash/keys.rb
class Hash
  # Returns a new hash with all keys converted using the block operation.
  #
  #  hash = { name: 'Rob', age: '28' }
  #
  #  hash.transform_keys{ |key| key.to_s.upcase }
  #  # => {"NAME"=>"Rob", "AGE"=>"28"}
  def transform_keys
    return enum_for(:transform_keys) unless block_given?
    result = self.class.new
    each_key do |key|
      result[yield(key)] = self[key]
    end
    result
  end

  # Destructively convert all keys using the block operations.
  # Same as transform_keys but modifies +self+.
  def transform_keys!
    return enum_for(:transform_keys!) unless block_given?
    keys.each do |key|
      self[yield(key)] = delete(key)
    end
    self
  end

  # Returns a new hash with all keys converted to strings.
  #
  #   hash = { name: 'Rob', age: '28' }
  #
  #   hash.stringify_keys
  #   # => {"name"=>"Rob", "age"=>"28"}
  def stringify_keys
    transform_keys(&:to_s)
  end

  # Destructively convert all keys to strings. Same as
  # +stringify_keys+, but modifies +self+.
  def stringify_keys!
    transform_keys!(&:to_s)
  end

  # Returns a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  #
  #   hash = { 'name' => 'Rob', 'age' => '28' }
  #
  #   hash.symbolize_keys
  #   # => {:name=>"Rob", :age=>"28"}
  def symbolize_keys
    transform_keys do |key|
      begin
        key.to_sym
      rescue
        key
      end
    end
  end
  alias to_options symbolize_keys

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. Same as +symbolize_keys+, but modifies +self+.
  def symbolize_keys!
    transform_keys! do |key|
      begin
        key.to_sym
      rescue
        key
      end
    end
  end
  alias to_options! symbolize_keys!

  # Validate all keys in a hash match <tt>*valid_keys</tt>, raising
  # ArgumentError on a mismatch.
  #
  # Note that keys are treated differently than HashWithIndifferentAccess,
  # meaning that string and symbol keys will not match.
  #
  #   { name: 'Rob', years: '28' }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key: :years. Valid keys are: :name, :age"
  #   { name: 'Rob', age: '28' }.assert_valid_keys('name', 'age') # => raises "ArgumentError: Unknown key: :name. Valid keys are: 'name', 'age'"
  #   { name: 'Rob', age: '28' }.assert_valid_keys(:name, :age)   # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    valid_keys.flatten!
    each_key do |k|
      unless valid_keys.include?(k)
        raise ArgumentError, "Unknown key: #{k.inspect}. Valid keys are: #{valid_keys.map(&:inspect).join(', ')}"
      end
    end
  end

  # Returns a new hash with all keys converted by the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  #
  #  hash = { person: { name: 'Rob', age: '28' } }
  #
  #  hash.deep_transform_keys{ |key| key.to_s.upcase }
  #  # => {"PERSON"=>{"NAME"=>"Rob", "AGE"=>"28"}}
  def deep_transform_keys(&block)
    _deep_transform_keys_in_object(self, &block)
  end

  # Destructively convert all keys by using the block operation.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_transform_keys!(&block)
    _deep_transform_keys_in_object!(self, &block)
  end

  # Returns a new hash with all keys converted to strings.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  #
  #   hash = { person: { name: 'Rob', age: '28' } }
  #
  #   hash.deep_stringify_keys
  #   # => {"person"=>{"name"=>"Rob", "age"=>"28"}}
  def deep_stringify_keys
    deep_transform_keys(&:to_s)
  end

  # Destructively convert all keys to strings.
  # This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_stringify_keys!
    deep_transform_keys!(&:to_s)
  end

  # Returns a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+. This includes the keys from the root hash
  # and from all nested hashes and arrays.
  #
  #   hash = { 'person' => { 'name' => 'Rob', 'age' => '28' } }
  #
  #   hash.deep_symbolize_keys
  #   # => {:person=>{:name=>"Rob", :age=>"28"}}
  def deep_symbolize_keys
    deep_transform_keys do |key|
      begin
        key.to_sym
      rescue
        key
      end
    end
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+. This includes the keys from the root hash and from all
  # nested hashes and arrays.
  def deep_symbolize_keys!
    deep_transform_keys! do |key|
      begin
        key.to_sym
      rescue
        key
      end
    end
  end

  private

  # support methods for deep transforming nested hashes and arrays
  def _deep_transform_keys_in_object(object, &block)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[yield(key)] = _deep_transform_keys_in_object(value, &block)
      end
    when Array
      object.map { |e| _deep_transform_keys_in_object(e, &block) }
    else
      object
    end
  end

  def _deep_transform_keys_in_object!(object, &block)
    case object
    when Hash
      object.keys.each do |key|
        value = object.delete(key)
        object[yield(key)] = _deep_transform_keys_in_object!(value, &block)
      end
      object
    when Array
      object.map! { |e| _deep_transform_keys_in_object!(e, &block) }
    else
      object
    end
  end
end
