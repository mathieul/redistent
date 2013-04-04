require "spec_helper"
require "music_classes"
require "redis_helper"

describe Redistent::Collectioner do
  include RedisHelper

  let(:key)          { Nest.new("collectioner", redis) }
  let(:collectioner) { Redistent::Collectioner.new(key, config.models) }

  pending
end
