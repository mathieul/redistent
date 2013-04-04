require "spec_helper"
require "music_classes"
require "redis_helper"

describe Redistent::Collectioner do
  include RedisHelper

  let(:key)          { Nest.new("collectioner", redis) }
  let(:locker)       { double(:locker) }
  let(:collectioner) { Redistent::Collectioner.new(key, config.models, locker) }
  let(:band)         { Band.new(uid: "12") }

  context "referenced collection" do
    it "returns a collection if it exists" do
      Redistent::Collection.should_receive(:new) do |ze_model, ze_key, ze_locker, description|
        expect(ze_model).to eq(band)
        expect(ze_key).to eq(key)
        expect(ze_locker).to eq(locker)
        expect(description.model).to eq(:musician)
        expect(description.type).to eq(:referenced)
        expect(description.attribute).to eq(:band_uid)
      end
      collection = collectioner.collection(band, :musicians)
    end

    it "raises an error if the collection doesn't exist" do
      expect { collectioner.collection(band, :blah) }.to raise_error(Redistent::ConfigError)
      expect { collectioner.collection(Object.new, :zorglub) }.to raise_error(Redistent::ConfigError)
    end
  end
end
