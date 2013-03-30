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
  def persisted!
    @persisted = true
  end
  def persisted?
    !!@persisted
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
  def persisted!
    @persisted = true
  end
  def persisted?
    !!@persisted
  end
end

class Instrument
  include Virtus
  attr_accessor :id
  attribute :name, String
  attribute :type, String
  attribute :musician, Musician
  def complete?
    name && type && musician
  end
  def persisted!
    @persisted = true
  end
  def persisted?
    !!@persisted
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
  let(:metallica) { Band.new(id: "42", name: "Metallica") }
  let(:james)     { Musician.new(id: "12", name: "James Hetfield", band: metallica) }
  let(:guitar)    { Instrument.new(id: "7" ,name: "Jame's guitar", type: "guitar", musician: james) }

  context "write simple model" do
    it "sets the model id if not set" do
      metallica.id = nil
      writer.write(metallica)
      expect(metallica.id).to eq("1")
    end

    it "doesn't set the model id if already set" do
      writer.write(metallica)
      expect(metallica.id).to eq("42")
    end

    it "adds the model id to the list of all model ids" do
      writer.write(metallica)
      expect(redis.smembers("writer:Band:all")).to eq(["42"])
    end

    it "stores the model attributes" do
      writer.write(metallica)
      attributes = BSON.deserialize(redis.get("writer:Band:42"))
      expect(attributes).to eq("name" => "Metallica")
    end

    it "tells the model it has been persisted" do
      metallica.should_receive(:persisted!)
      writer.write(metallica)
    end

    it "raises an error if the model is not described" do
      expect { writer.write(guitar) }.to raise_error(Redistent::ConfigError)
    end

    it "saves in a transactions all models passed to be written" do
      james.should_receive(:attributes).and_raise("simulated error")
      expect { writer.write(metallica, james) }.to raise_error("simulated error")
      expect(redis.smembers("writer:Band:all")).to be_empty
      expect(redis.smembers("writer:Musician:all")).to be_empty
      expect(metallica).to_not be_persisted
    end
  end

  context "write model with reference" do
    it "saves the reference id instead of the object" do
      writer.write(metallica)
      writer.write(james)
      attributes = BSON.deserialize(redis.get("writer:Musician:12"))
      expect(attributes).to eq("name" => "James Hetfield", "band_id" => "42")
    end

    it "saves the referenced objects if necessary" do
      config.add_model :instrument do
        references :musician
      end
      writer.write(guitar)
      expect(redis.smembers("writer:Band:all")).to eq(["42"])
      expect(redis.smembers("writer:Musician:all")).to eq(["12"])
      expect(redis.smembers("writer:Instrument:all")).to eq(["7"])
    end
  end
end
