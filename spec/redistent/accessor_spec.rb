require "spec_helper"
require "music_classes"

describe Redistent::Accessor do
  let(:klass) { Class.new.tap { |klass| klass.send(:include, Redistent::Accessor) } }

  context "a new instance" do
    it "is initialized with redis config" do
      accessor = klass.new(url: "redis://127.0.0.1:6379/7")
      expect(accessor.key.redis.client.port).to eq(6379)
    end

    it "finalizes the config" do
      klass.config.should_receive(:finalize!)
      klass.new(redis_config)
    end
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

    it "specify the namespace with #namespace" do
      klass.model :team
      klass.namespace Hash
      expect(config.models[:team].namespace).to eq(Hash)
    end

    it "forwards the model definition block to the config object if any" do
      block_caller = nil
      klass.model :queue do
        block_caller = self
      end
      expect(block_caller).to eq(config)
    end
  end

  context "accessor operations" do
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
  end

  context "exclusif access to redis connection" do
    let(:accessor) { klass.new(redis_config) }

    it "exposes the use of its unique mutex" do
      operation = ->(messages) { messages << :start; sleep 0.2; messages << :finish }

      parallel = []
      threads = Array.new(5).map do
        Thread.new { operation.call(parallel) }
      end
      threads.each(&:join)
      expect(parallel).to eq([:start] * 5 + [:finish] * 5)

      sequential = []
      threads = Array.new(5).map do
        Thread.new do
          accessor.with_lock { operation.call(sequential) }
        end
      end
      threads.each(&:join)
      expect(sequential).to eq([:start, :finish] * 5)
    end

    it "doesn't execute more than one operation at a time" do
      # klass for the delegate double that will just push messages and sleep
      delegate_klass = Struct.new(:messages) do
        def write(*args)
          messages << :start
          sleep 0.1
          messages << :finish
        end
        alias :read :write
        alias :erase :write
      end
      # use the delegate double rather than the accessor delegates
      accessor.instance_eval do
        @delegate = delegate_klass.new([])
        def delegate; @delegate; end
        alias :writer :delegate
        alias :reader :delegate
        alias :eraser :delegate
        def messages; delegate.messages; end
      end

      threads = []
      threads << Thread.new { accessor.read }
      threads << Thread.new { accessor.write }
      threads << Thread.new { accessor.erase }
      threads.each(&:join)
      expect(accessor.messages).to eq([:start, :finish, :start, :finish, :start, :finish])
    end
  end

  context "referenced collection" do
    let(:band) { MusicClasses::Band.new(uid: "12") }
    let(:accessor) { klass.new(redis_config) }
    before(:each) do
      klass.config.add_model :musician do
        references :band
      end
    end

    it "returns a collection if it exists" do
      Redistent::Collection.should_receive(:new) do |ze_accessor, ze_model, description|
        expect(ze_accessor).to eq(accessor)
        expect(ze_model).to eq(band)
        expect(description.model).to eq(:musician)
        expect(description.type).to eq(:referenced)
        expect(description.attribute).to eq(:band_uid)
      end
      collection = accessor.collection(band, :musicians)
    end

    it "raises an error if the collection doesn't exist" do
      expect { accessor.collection(band, :blah) }.to raise_error(Redistent::CollectionNotFound)
      expect { accessor.collection(Object.new, :zorglub) }.to raise_error(Redistent::ConfigError)
    end
  end
end
