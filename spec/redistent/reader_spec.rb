require "spec_helper"
require "music_classes"

describe Redistent::Reader do
  let(:redis)     { Redis.new(redis_config) }
  let(:key)       { Nest.new("reader", redis) }
  # let(:config) do
  #   Redistent::Config.new.tap do |config|
  #     config.add_hook  :before_write, :complete?
  #     config.add_model :band
  #     config.add_model :musician do
  #       references :band
  #     end
  #   end
  # end
  let(:reader)    { Redistent::Reader.new(key, config.models) }
end
