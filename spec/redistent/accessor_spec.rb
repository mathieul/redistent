require "spec_helper"

describe Redistent::Accessor do
  let(:klass) { Class.new.tap { |klass| klass.send(:include, Redistent::Accessor) } }

  it "is initialized with redis config" do
    accessor = klass.new(url: "redis://127.0.0.1:6379/7")
    expect(accessor.db.client.port).to eq(6379)
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
end