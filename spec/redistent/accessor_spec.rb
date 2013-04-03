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
      klass.before_write { |model| "arg is #{model}" }
      expect(config.hooks[:before_write].first).to eq(:message_name)
      expect(config.hooks[:before_write].last.call("hello")).to eq("arg is hello")
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

    it "delegates #erase to an eraser" do
      Redistent::Eraser.any_instance.should_receive(:erase).with(:the, :arguments)
      accessor.erase(:the, :arguments)
    end

    it "doesn't execute more than one operation at a time" do
      delegate_klass = Struct.new(:messages) do
        def write(*args)
          messages << :start
          sleep 0.1
          messages << :finish
        end
        alias :read :write
        alias :erase :write
      end
      accessor.instance_eval do
        @delegate = delegate_klass.new([])
        def delegate; @delegate; end
        alias :writer :delegate
        alias :reader :delegate
        alias :eraser :delegate
        def messages; delegate.messages; end
      end
      threads = Array.new(5).map do
        Thread.new { accessor.read }
        Thread.new { accessor.write }
        Thread.new { accessor.erase }
      end
      threads.each(&:join)
      expect(accessor.messages).to eq([:start, :finish] * 15)
    end
  end
end
