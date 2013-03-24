require "pry"
require "redis"
require "coveralls"

require File.join(__dir__, "..", "lib", "redistent")

Coveralls.wear!

module GlobalConfigHelpers
  def redis_config
    {url: "redis://127.0.0.1:6379/7"}
  end

  def redis
    @redis ||= Redis.new(redis_config)
  end
end

RSpec.configure do |config|
  config.include GlobalConfigHelpers
  config.after(:each) { redis.flushdb }
end
