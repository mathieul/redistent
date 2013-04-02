require "spec_helper"
require "music_classes"
require "redis_helper"

describe Redistent::Eraser do
  include RedisHelper

  let(:key)       { Nest.new("eraser", redis) }
  let(:eraser)    { Redistent::Eraser.new(key, config.models) }

  context "erase simple model" do
    pending
  end
end
