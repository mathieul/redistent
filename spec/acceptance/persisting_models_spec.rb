require "acceptance_helper"
require "virtus"

class Task
  include Virtus
  attribute :title, String
  attribute :created_at, DateTime
end

class Queue
  include Virtus
  attribute :name, String
  embeds :tasks, score: ->(task) { task.created_ts } do
    define(:count)   { |key| key.zcard }
    define(:next_id) { |key| key.command(...read next id...) }
  end
end

class Teammate
  include Virtus
  attribute :name, String
end

class Skill
  include Virtus
  attribute :level, Integer
  references :queue
  references :teammate
end

feature "Persisting models" do
  let(:store)    { Redistent::DataStore.new(:redis, Redis, redis_config) }
  let(:queue)    { Queue.new(name: "Masada") }
  let(:teammate) { Teammate.new(name: "John Zorn") }
  let(:skill)    { Skill.new(queue: queue, teammate: teammate, level: 50) }
  let(:task)     { Task.new(title: "Alef")}

  scenario "Save and reload a model" do
    store.save(queue)
    expect(store.get(:queue, queue.id).name).to eq("Masada")
  end
end
