require "spec_helper"
require "virtus"
require "bson"

class Band
  include Virtus
  attr_accessor :uid
  attribute :name, String
  def complete?
    name && name.length > 0
  end
end

class Musician
  include Virtus
  attr_accessor :uid
  attribute :name, String
  attribute :band, Band
  def complete?
    band && name && name.length > 0
  end
end

class Instrument
  include Virtus
  attr_accessor :uid
  attribute :name, String
  attribute :type, String
  attribute :musician, Musician
  def complete?
    name && type && musician
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
  let(:guitar)    { Instrument.new(name: "Jame's guitar", type: "guitar", musician: james) }

  context "write simple model" do
    it "can get the next uid" do
      expect(writer.next_uid).to eq("1")
    end

    it "sets the model uid if not set" do
      writer.should_receive(:next_uid).and_return("123")
      writer.write(metallica)
      expect(metallica.uid).to eq("123")
    end

    it "doesn't set the model uid if already set" do
      metallica.uid = "42"
      writer.write(metallica)
      expect(metallica.uid).to eq("42")
    end

    it "adds the model uid to the list of all model uids" do
      writer.should_receive(:next_uid).and_return("456")
      writer.write(metallica)
      expect(redis.smembers("writer:Band:all")).to eq(["456"])
    end

    it "stores the model attributes" do
      writer.should_receive(:next_uid).and_return("789")
      writer.write(metallica)
      attributes = BSON.deserialize(redis.get("writer:Band:789"))
      expect(attributes).to eq("name" => "Metallica")
    end

    it "raises an error if the model is not described" do
      expect { writer.write(guitar) }.to raise_error(Redistent::ConfigError)
    end

    it "saves all models passed to be written in a transaction" do
      james.should_receive(:attributes).and_raise("simulated error")
      expect { writer.write(metallica, james) }.to raise_error("simulated error")
      expect(redis.smembers("writer:Band:all")).to be_empty
      expect(redis.smembers("writer:Musician:all")).to be_empty
      expect(metallica.uid).to be_nil
    end
  end

  context "write model with reference" do
    it "saves the reference uid instead of the object" do
      writer.should_receive(:next_uid).and_return("123")
      writer.should_receive(:next_uid).and_return("456")
      writer.write(metallica)
      writer.write(james)
      attributes = BSON.deserialize(redis.get("writer:Musician:456"))
      expect(attributes).to eq("name" => "James Hetfield", "band_uid" => "123")
    end

    it "saves the referenced objects if necessary" do
      config.add_model :instrument do
        references :musician
      end
      guitar.uid = "7"
      guitar.musician.uid = "12"
      guitar.musician.band.uid = "42"
      writer.write(guitar)
      expect(redis.smembers("writer:Instrument:all")).to eq(["7"])
      expect(redis.smembers("writer:Musician:all")).to eq(["12"])
      expect(redis.smembers("writer:Band:all")).to eq(["42"])
    end
  end
end
