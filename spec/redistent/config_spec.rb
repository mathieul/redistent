require "spec_helper"

describe Redistent::Config do
  let(:config) { Redistent::Config.new }

  context "adding hooks" do
    it "adds a message hook with #add_hook(:symbol)" do
      config.add_hook(:hook_name, :message)
      expect(config.hooks).to eq(hook_name: [:message])
    end

    it "adds a block hook with #add_hook(&block)" do
      config.add_hook(:hook_name) { "result" }
      expect(config.hooks[:hook_name].first.call).to eq("result")
    end
  end

  context "adding models" do
    it "adds a model with #add_model" do
      config.add_model(:name)
      expect(config.models[:name].persist_attributes).to be_true
    end

    it "adds a reference to a model with #references" do
      config.add_model :queue do
        references :team
      end
      expect(config.models[:queue]).to have(1).references
      reference = config.models[:queue].references.first
      expect(reference.model).to eq(:team)
      expect(reference.attribute).to eq(:team_uid)
    end

    it "adds an implicit collection to the referenced model" do
      config.add_model :queue do
        references :team
      end
      collection = config.models[:team].collections[:queues]
      expect(collection.type).to eq(:referenced)
      expect(collection.model).to eq(:queue)
    end

    it "defines a sorted collection with #collection with a sort_by option" do
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
      expect {
        config.add_model :queue do
          collection :teammates, via: :skills, sort_by: :name
        end
      }.to raise_error(Redistent::ConfigError)
    end
  end

  context "access the configuration" do
    it "can access hooks within each model definition" do
      config.add_hook(:before_write, :run_me)
      config.add_model(:model_name)
      expect(config.models[:model_name].hooks[:before_write]).to eq([:run_me])
    end

    it "connects references to collections after finalization" do
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
