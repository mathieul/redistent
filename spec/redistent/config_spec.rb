require "spec_helper"

describe Redistent::Config do
  let(:config) { Redistent::Config.new }

  it "adds a hook with #add_hook" do
    config.add_hook(:hook_name, :message)
    expect(config.hooks).to eq(hook_name: [:message])
  end

  it "adds a model with #add_model" do
    config.add_model(:name)
    expect(config.models[:name]).to eq(persist_attributes: true)
  end

  it "adds a reference to a model with #references" do
    config.add_model :queue do
      references :team
    end
    expect(config.models[:queue][:references]).to eq([{model: :team, attribute: :team_id}])
  end

  it "defines an embedded collection with #embeds" do
    config.add_model :queue do
      embeds :tasks
    end
    expect(config.models[:queue][:collections]).to eq([
      {type: :embedded, sort_by: false, model: :task, attribute: :task_id}
    ])
  end

  it "defines a sorted embedded collection with #embeds with a sort_by option" do
    config.add_model :queue do
      embeds :tasks, sort_by: :queued_at
    end
    expect(config.models[:queue][:collections]).to eq([
      {type: :embedded, sort_by: :queued_at, model: :task, attribute: :task_id}
    ])
  end

  it "defines methods on an embedded collection with #define" do
    called_with = nil
    config.add_model :queue do
      embeds :tasks do
        define(:testing) { |key| called_with = key }
      end
    end
    config.models[:queue][:collections].first[:methods][:testing].call(:test)
    expect(called_with).to eq(:test)
  end

  it "defines an indirect collection with #collection and :via option" do
    config.add_model :queue do
      collection :teammates, via: :skills
    end
    expect(config.models[:queue][:collections]).to eq([{
      type: :referenced, model: :skill, attribute: :skill_id,
      target: :teammate, target_attribute: :teammate_id
    }])
  end
end
