require "acceptance_helper"
require "virtus"

class TaskQueue
  include Virtus
  attr_accessor :id
  attribute :name, String
end

class Task
  include Virtus
  attr_accessor :id
  attribute :title, String
  attribute :queue, TaskQueue
  attribute :queued_at, DateTime
end

class Team
  include Virtus
  attr_accessor :id
  attribute :name, String
end

class Teammate
  include Virtus
  attr_accessor :id
  attribute :name, String
  attribute :team, Team
end

class Skill
  include Virtus
  attr_accessor :id
  attribute :level, Integer
  attribute :queue, TaskQueue
  attribute :teammate, Teammate
end

class PersistentAccessor
  include Redistent::Accessor
  before_write :valid?
  model :queue do
    embeds :tasks, sort_by: :queued_at do
      define(:count)   { |key| key.zcard }
      define(:next_id) { |key| key.zrangebyscore("-inf", "+inf", limit: [0, 1]).first }
    end
    collection :teammates, via: :skills
  end
  model :teammate do
    references :team
    collection :queues, via: :skills
  end
  model :skill do
    references :queue
    references :teammate
  end
end

feature "persisting models" do
  let(:accessor) { PersistentAccessor.new(redis_config) }

  scenario "write, reload and erase a model" do
    queue = TaskQueue.new(name: "fix bugs")
    accessor.write(queue)

    reloaded = accessor.read(:queue, queue.id)
    expect(reloaded.name).to eq("fix bugs")

    accessor.erase(reloaded)
    expect(accessor.read(:queue, queue.id)).to be_nil
  end

  scenario "write a model with references and reload it with references" do
    queue = TaskQueue.new(name: "fix bugs")
    teammate = Teammate.new(name: "John Doe")
    skill = Skill.new(queue: queue, teammate: teammate, level: 50)
    accessor.write(skill)

    reloaded = accessor.read(:skill, skill.id)
    expect(reloaded.level).to eq(skill.level)
    expect(reloaded.queue).to eq(skill.queue)
    expect(reloaded.teammate).to eq(skill.teammate)
  end

  scenario "query a model's referrers" do
    team = Team.new(name: "engineering")
    teammate = Teammate.new(name: "John Doe", team: team)
    other = Teammate.new(name: "Jane Doe", team: team)
    accessor.write(teammate, other)
    reloaded_team = accessor.read(:team, teammate.team.id)

    referrers = accessor.collection(reloaded_team, :teammates)
    expect(referrers.count).to eq(2)
    expect(referrers.all.map(&:name).sort).to eq(["Jane Doe", "John Doe"])
  end

  scenario "query a model's embedded collection" do
    queue = TaskQueue.new(name: "fix bugs")
    task1 = Task.new(title: "bug #123")
    task2 = Task.new(title: "bug #456")
    accessor.write(queue, task1, task2)

    accessor.collection(queue, :tasks) << task2
    accessor.collection(queue, :tasks) << task1

    queue = accessor.read(:queue, queue.id)
    collection = accessor.collection(queue, :tasks)
    expect(collection.count).to eq(2)
    expect(collection.next_id).to eq(task2)
  end
end
