require "spec_helper"

describe Redistent::Config do
  let(:config) { Redistent::Config.new }

  context "describe the configuration" do
    it "adds a message hook with #add_hook(:symbol)" do
      config.add_hook(:hook_name, :message)
      expect(config.hooks).to eq(hook_name: [:message])
    end

    it "adds a block hook with #add_hook(&block)" do
      config.add_hook(:hook_name) { "result" }
      expect(config.hooks[:hook_name].first.call).to eq("result")
    end

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

    it "defines an embedded collection with #embeds" do
      config.add_model :queue do
        embeds :tasks
      end
      expect(config.models[:queue]).to have(1).collections
      collection = config.models[:queue].collections.first
      expect(collection.type).to eq(:embedded)
      expect(collection.sort_by).to be_false
      expect(collection.model).to eq(:task)
      expect(collection.attribute).to eq(:task_uid)
    end

    it "defines a sorted embedded collection with #embeds with a sort_by option" do
      config.add_model :queue do
        embeds :tasks, sort_by: :queued_at
      end
      expect(config.models[:queue].collections.first.sort_by).to eq(:queued_at)
    end

    it "defines methods on an embedded collection with #define" do
      called_with = nil
      config.add_model :queue do
        embeds :tasks do
          define(:testing) { |key| called_with = key }
        end
      end
      config.models[:queue].collections.first.methods[:testing].call(:test)
      expect(called_with).to eq(:test)
    end

    it "defines an indirect collection with #collection and :via option" do
      config.add_model :queue do
        collection :teammates, via: :skills
      end
      expect(config.models[:queue]).to have(1).collections
      collection = config.models[:queue].collections.first
      expect(collection.type).to eq(:referenced)
      expect(collection.model).to eq(:skill)
      expect(collection.attribute).to eq(:skill_uid)
      expect(collection.target).to eq(:teammate)
      expect(collection.target_attribute).to eq(:teammate_uid)
    end
  end

  context "access the configuration" do
    it "can access hooks within each model definition" do
      config.add_hook(:before_write, :run_me)
      config.add_model(:model_name)
      expect(config.models[:model_name].hooks[:before_write]).to eq([:run_me])
    end
  end
end
