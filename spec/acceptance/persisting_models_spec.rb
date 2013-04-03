require "acceptance_helper"
require "virtus"
require "scrivener"

class TaskQueue
  include Virtus
  include Scrivener::Validations
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  def validate
    assert_present :name
  end
end

class Task
  include Virtus
  include Scrivener::Validations
  attr_accessor :uid, :persisted_attributes
  attribute :title, String
  attribute :task_queue, TaskQueue
  attribute :queued_at, DateTime
  def validate
    assert_present :title
  end
end

class Team
  include Virtus
  include Scrivener::Validations
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  def validate
    assert_present :name
  end
end

class Teammate
  include Virtus
  include Scrivener::Validations
  attr_accessor :uid, :persisted_attributes
  attribute :name, String
  attribute :team, Team
  def validate
    assert_present :name
    assert_present :team
  end
end

class Skill
  include Virtus
  include Scrivener::Validations
  attr_accessor :uid, :persisted_attributes
  attribute :level, Integer
  attribute :task_queue, TaskQueue
  attribute :teammate, Teammate
  def validate
    %i[level task_queue teammate].each { |name| assert_present(name) }
    assert_numeric :level
  end
end

class PersistentAccessor
  include Redistent::Accessor
  before_write do |model|
    unless model.valid?
      messages = model.errors.map do |attribute, errors|
        "#{attribute} is #{errors.join(", ")}"
      end
      raise "#{model.class}: #{messages.join(" - ")}"
    end
  end
  model :team
  model :teammate do
    references :team
    collection :task_queues, via: :skills
  end
  model :task_queue do
    embeds :tasks, sort_by: :queued_at do
      define(:count)    { |key| key.zcard }
      define(:next_uid) { |key| key.zrangebyscore("-inf", "+inf", limit: [0, 1]).first }
    end
    collection :teammates, via: :skills
  end
  model :skill do
    references :task_queue
    references :teammate
  end
end

feature "persisting models" do
  let(:accessor) { PersistentAccessor.new(redis_config) }

  scenario "write, reload and erase a model" do
    queue = TaskQueue.new(name: "fix bugs")
    accessor.write(queue)

    reloaded = accessor.read(:task_queue, queue.uid)
    expect(reloaded.name).to eq("fix bugs")

    accessor.erase(reloaded)
    expect { accessor.read(:task_queue, queue.uid) }.to raise_error
  end

  scenario "write a model with references and reload it with references" do
    queue = TaskQueue.new(name: "fix bugs")
    teammate = Teammate.new(name: "John Doe", team: Team.new(name: "Anonymous"))
    skill = Skill.new(task_queue: queue, teammate: teammate, level: 50)
    accessor.write(skill)

    reloaded = accessor.read(:skill, skill.uid)
    expect(reloaded.level).to eq(skill.level)
    expect(reloaded.task_queue.uid).to eq(skill.task_queue.uid)
    expect(reloaded.teammate.uid).to eq(skill.teammate.uid)
  end

  scenario "query a model's referrers" do
    pending
    team = Team.new(name: "engineering")
    teammate = Teammate.new(name: "John Doe", team: team)
    other = Teammate.new(name: "Jane Doe", team: team)
    accessor.write(teammate, other)
    reloaded_team = accessor.read(:team, teammate.team.uid)

    referrers = accessor.collection(reloaded_team, :teammates)
    expect(referrers.count).to eq(2)
    expect(referrers.all.map(&:name).sort).to eq(["Jane Doe", "John Doe"])
  end

  scenario "query a model's embedded collection" do
    pending
    queue = TaskQueue.new(name: "fix bugs")
    task1 = Task.new(title: "bug #123")
    task2 = Task.new(title: "bug #456")
    accessor.write(queue, task1, task2)

    accessor.collection(queue, :tasks) << task2
    accessor.collection(queue, :tasks) << task1

    queue = accessor.read(:task_queue, queue.uid)
    collection = accessor.collection(queue, :tasks)
    expect(collection.count).to eq(2)
    expect(collection.next_uid).to eq(task2)
  end
end
