require "acceptance_helper"
require "virtus"

class Task
  include Virtus
  attr_reader :id
  attribute :title, String
  attribute :queue, Queue
  attribute :queued_at, DateTime
end

class Queue
  include Virtus
  attr_reader :id
  attribute :name, String
end

class Team
  include Virtus
  attr_reader :id
  attribute :name, String
end

class Teammate
  include Virtus
  attr_reader :id
  attribute :name, String
  attribute :team, Team
end

class Skill
  include Virtus
  attr_reader :id
  attribute :level, Integer
  attribute :queue, Queue
  attribute :teammate, Teammate
end

class PersistentAccessor
  include Redistent::Accessor
  model :queue do
    embeds :tasks, score: ->(task) { task.created_ts } do
      define(:count)   { |key| key.zcard }
      define(:next_id) { |key| key.zrangebyscore("-inf", "+inf", limit: [0, 1]).first }
    end
    collection :skills
    collection :teammates, through: :skills
  end
  model :teammate do
    references :team
    collection :skills
    collection :queues, through: :skills
  end
  model :skill do
    references :queue
    references :teammate
  end
end

feature "persisting models" do
  let(:store) { PersistentAccessor.new(redis_config) }

  scenario "save, reload and delete a model" do
    queue = Queue.new(name: "fix bugs")
    store.save(queue)

    reloaded = store.get(:queue, queue.id)
    expect(reloaded.name).to eq("fix bugs")

    store.delete(reloaded)
    expect(store.get(:queue, queue.id)).to be_nil
  end

  scenario "save a model with references and reload it with references" do
    queue = Queue.new(name: "fix bugs")
    teammate = Teammate.new(name: "John Doe")
    skill = Skill.new(queue: queue, teammate: teammate, level: 50)
    store.save(skill)

    reloaded = store.get(:skill, skill.id)
    expect(reloaded.level).to eq(skill.level)
    expect(reloaded.queue).to eq(skill.queue)
    expect(reloaded.teammate).to eq(skill.teammate)
  end

  scenario "query a model's referrers" do
    team = Team.new(name: "engineering")
    teammate = Teammate.new(name: "John Doe", team: team)
    other = Teammate.new(name: "Jane Doe", team: team)
    store.save(teammate, other)
    reloaded_team = store.get(:team, teammate.team.id)

    referrers = store.collection(reloaded_team, :teammates)
    expect(referrers.count).to eq(2)
    expect(referrers.all.map(&:name).sort).to eq(["Jane Doe", "John Doe"])
  end

  scenario "query a model's embedded collection" do
    queue = Queue.new(name: "fix bugs")
    task1 = Task.new(title: "bug #123")
    task2 = Task.new(title: "bug #456")
    store.save(queue, task1, task2)

    collection = store.embedded_in(queue, :tasks)
    collection << task2
    collection << task1

    queue = store.get(:queue, queue.id)
    collection = store.collection(queue, :tasks)
    expect(collection.count).to eq(2)
    expect(collection.next_id).to eq(task2)
  end
end
