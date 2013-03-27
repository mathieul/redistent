require "spec_helper"
require "virtus"
require "bson"

class Band
  include Virtus
  attr_accessor :id
  attribute :name, String
  def complete?
    name && name.length > 0
  end
end

class Musician
  include Virtus
  attr_accessor :id
  attribute :name, String
  attribute :band, Band
  def complete?
    band && name && name.length > 0
  end
end

describe Redistent::Writer do
  let(:redis)     { Redis.new(redis_config) }
  let(:key)       { Nest.new("writer", redis) }
  let(:config) do
    Redistent::Config.new.tap do |config|
      config.add_hook  :before_write, :complete?
      config.add_model :band
      config.add_model :musician do
        references :band
      end
    end
  end
  let(:writer)    { Redistent::Writer.new(key, config.models) }
  let(:metallica) { Band.new(name: "Metallica") }
  let(:james)     { Musician.new(name: "James Hetfield", band: metallica) }

  context "#write" do
    it "sets the model id if not set" do
      writer.write(metallica)
      expect(metallica.id).to eq("1")
    end

    it "doesn't set the model id if already set" do
      metallica.id = "42"
      writer.write(metallica)
      expect(metallica.id).to eq("42")
    end

    it "adds the model id to the list of all model ids" do
      metallica.id = "12"
      writer.write(metallica)
      expect(redis.smembers("writer:Band:all")).to eq(["12"])
    end

    it "stores the model attributes" do
      metallica.id = "12"
      writer.write(metallica)
      attributes = BSON.deserialize(redis.get("writer:Band:12"))
      expect(attributes).to eq("name" => "Metallica")
    end
  end
end
