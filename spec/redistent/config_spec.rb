require "spec_helper"

describe Redistent::Config do
  let(:config) { Redistent::Config.new }

  context "adding hooks" do
    it "adds a hook with #add_hook(&block)" do
      config.add_hook(:hook_name) { "result" }
      expect(config.hooks[:hook_name].first.call).to eq("result")
    end
  end

  context "adding models" do
    it "adds a model with #add_model" do
      config.add_model(:something)
      expect(config.models[:something].name).to eq(:something)
    end

    it "sets the namespace with #set_namespace" do
      config.add_model(:blah)
      expect(config.models[:blah].namespace).to eq(Object)
      config.set_namespace(Hash)
      expect(config.models[:blah].namespace).to eq(Hash)
    end

    context "#index" do
      it "adds an index to a model" do
        config.add_model :queue do
          index :team
        end
        expect(config.models[:queue]).to have(1).indices
        index = config.models[:queue].indices.first
        expect(index.model).to eq(:team)
        expect(index.attribute).to eq(:team_uid)
      end

      it "can request inlining the reference with :inline_reference" do
        config.add_model :queue do
          index :team, inline_reference: true
        end
        expect(config.models[:queue].indices.first.inline_reference).to be_true
      end
    end

    context "#collection" do
      let(:collection) { config.models[:queue].collections[:teammates] }

      it "has a name" do
        config.add_model(:queue) { collection :teammates }
        expect(collection.name).to eq(:teammates)
      end

      it "has a model" do
        config.add_model(:queue) { collection :teammates, model: :mate }
        expect(collection.model).to eq(:mate)
      end

      it "infers a model when not explicit" do
        config.add_model(:queue) { collection :teammates }
        expect(collection.model).to eq(:teammate)
      end
    end

    it "defines a sorted collection with #collection with a sort_by option" do
      pending
      config.add_model :queue do
        collection :tasks, sort_by: :queued_at
      end
      collection = config.models[:queue].collections[:tasks]
      expect(collection.type).to eq(:sorted)
      expect(collection.model).to eq(:task)
      expect(collection.attribute).to eq(:task_uids)
      expect(collection.sort_by).to eq(:queued_at)
    end

    it "defines an indirect collection with #collection and :via option" do
      pending
      config.add_model :queue do
        collection :teammates, via: :skills
      end
      collection = config.models[:queue].collections[:teammates]
      expect(collection.type).to eq(:indirect)
      expect(collection.model).to eq(:skill)
      expect(collection.attribute).to eq(:queue_uid)
      expect(collection.target).to eq(:teammate)
      expect(collection.target_attribute).to eq(:teammate_uid)
    end

    it "raises an error if both :via and :sort_by are used" do
      pending
      expect {
        config.add_model :queue do
          collection :teammates, via: :skills, sort_by: :name
        end
      }.to raise_error(Redistent::ConfigError)
    end
  end

  context "access the configuration" do
    it "can access hooks within each model definition" do
      pending
      config.add_hook(:before_write) { |model| "model: #{model}" }
      config.add_model(:model_name)
      hook = config.models[:model_name].hooks[:before_write].first
      expect(hook.call("Gisele")).to eq("model: Gisele")
    end

    it "connects references to collections after finalization" do
      pending
      config.add_model :team do
        collection :queues, sort_by: :priority
      end
      config.add_model :queue do
        references :team
      end

      config.finalize!
      reference = config.models[:team].collections[:queues].reference
      expect(reference.model).to eq(:team)
      expect(reference.attribute).to eq(:team_uid)
    end

    it "connects collections to references after finalization" do
      pending
      config.add_model :team do
        collection :queues
      end
      config.add_model :queue do
        references :team
      end

      config.finalize!
      collection = config.models[:queue].references.first.collection
      expect(collection.model).to eq(:queue)
      expect(collection.attribute).to eq(:queue_uid)
    end
  end
end
