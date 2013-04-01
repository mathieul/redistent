require "spec_helper"
require "redis_helper"
require "music_classes"

describe Redistent::Writer do
  include RedisHelper

  let(:key)       { Nest.new("writer", redis) }
  let(:writer)    { Redistent::Writer.new(key, config.models) }
  let(:metallica) { Band.new(name: "Metallica") }
  let(:james)     { Musician.new(name: "James Hetfield", band: metallica) }
  let(:guitar)    { Instrument.new(name: "Jame's guitar", type: "guitar", musician: james) }
  let(:mock_next_uids) { ->(uid) { writer.should_receive(:next_uid).and_return(uid) } }

  context "write simple model" do
    it "can get the next uid" do
      expect(writer.next_uid).to eq("1")
    end

    it "sets the model uid if not set" do
      mock_next_uids.call("123")
      writer.write(metallica)
      expect(metallica.uid).to eq("123")
    end

    it "doesn't set the model uid if already set" do
      metallica.uid = "42"
      writer.write(metallica)
      expect(metallica.uid).to eq("42")
    end

    it "adds the model uid to the list of all model uids" do
      mock_next_uids.call("456")
      writer.write(metallica)
      expect(redis.smembers("writer:Band:all")).to eq(["456"])
    end

    it "stores the model attributes" do
      mock_next_uids.call("789")
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

  context "write model with references" do
    it "saves the reference uid instead of the object" do
      %w[123 456].each(&mock_next_uids)
      writer.write(metallica)
      writer.write(james)
      attributes = BSON.deserialize(redis.get("writer:Musician:456"))
      expect(attributes).to eq("name" => "James Hetfield", "band_uid" => "123")
    end

    it "saves the referenced objects if necessary" do
      config.add_model :instrument do
        references :musician
      end
      %w[7 12 42].each(&mock_next_uids)
      writer.write(guitar)
      expect(redis.smembers("writer:Instrument:all")).to eq(["7"])
      expect(redis.smembers("writer:Musician:all")).to eq(["12"])
      expect(redis.smembers("writer:Band:all")).to eq(["42"])
    end

    it "saves an index per reference" do
      metallica.uid = "M39"
      james.uid = "J40"
      writer.write(james)
      expect(redis.smembers("writer:Musician:indices:band_uid:M39")).to eq(["J40"])
    end

    it "removes old references when updating a model", wip: true do
      suicidal = Band.new(uid: "S43", name: "Suicidal Tendencies")
      bob = Musician.new(uid: "B44", name: "Robert Trujillo", band: suicidal)
      writer.write(bob)
      expect(redis.smembers("writer:Musician:indices:band_uid:S43")).to eq(["B44"])
      metallica.uid = "M39"
      bob.band = metallica
      writer.write(bob)
      expect(redis.smembers("writer:Musician:indices:band_uid:S43")).to be_empty
      expect(redis.smembers("writer:Musician:indices:band_uid:M39")).to eq(["B44"])
    end
  end

  context "run hooks" do
    it "runs :before_write hooks before writing a model" do
      config.add_hook :before_write, :complete?
      metallica.should_receive(:complete?).and_raise("validation error")
      expect { writer.write(metallica) }.to raise_error("validation error")
    end
  end
end
