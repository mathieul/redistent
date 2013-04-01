require "spec_helper"

describe Redistent::Accessor do
  let(:klass) { Class.new.tap { |klass| klass.send(:include, Redistent::Accessor) } }

  it "is initialized with redis config" do
    accessor = klass.new(url: "redis://127.0.0.1:6379/7")
    expect(accessor.key.redis.client.port).to eq(6379)
  end

  context "DSL" do
    let(:config) { klass.config }

    it "adds a guard hook to run before writing with #before_write" do
      klass.before_write :message_name
      expect(config.hooks).to eq(before_write: [:message_name])
    end

    it "adds a model with #model" do
      klass.model :team
      expect(config.models.keys).to include(:team)
    end

    it "forwards the model definition block to the config object if any" do
      block_caller = nil
      klass.model :queue do
        block_caller = self
      end
      expect(block_caller).to eq(config)
    end
  end

  context "operations delegation" do
    let(:accessor) { klass.new(redis_config) }

    it "delegates #write to a writer" do
      Redistent::Writer.any_instance.should_receive(:write).with(:the, :arguments)
      accessor.write(:the, :arguments)
    end

    it "delegates #read to a reader" do
      Redistent::Reader.any_instance.should_receive(:read).with(:the, :arguments)
      accessor.read(:the, :arguments)
    end
  end
end
