require "acceptance_helper"
require "virtus"
require "scrivener"

module Models
  class TaskQueue
    include Virtus
    include Scrivener::Validations
    attr_accessor :uid, :persisted_attributes, :num_saved
    attribute :name, String
    def validate
      assert_present :name
    end
  end

  class Task
    include Virtus
    include Scrivener::Validations
    attr_accessor :uid, :persisted_attributes, :num_saved
    attribute :title, String
    attribute :task_queue, TaskQueue
    attribute :queued_at, Time
    def validate
      assert_present :title
    end
  end

  class Team
    include Virtus
    include Scrivener::Validations
    attr_accessor :uid, :persisted_attributes, :num_saved
    attribute :name, String
    def validate
      assert_present :name
    end
  end

  class Teammate
    include Virtus
    include Scrivener::Validations
    attr_accessor :uid, :persisted_attributes, :num_saved
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
    attr_accessor :uid, :persisted_attributes, :num_saved
    attribute :level, Integer
    attribute :task_queue, TaskQueue
    attribute :teammate, Teammate
    def validate
      %i[level task_queue teammate].each { |name| assert_present(name) }
      assert_numeric :level
    end
  end
end

class PersistentAccessor
  include Redistent::Accessor
  ModelNotValid = Class.new(StandardError)
  before_write { |model| raise ModelNotValid, model.errors unless model.valid? }
  after_write { |model| model.num_saved = (model.num_saved || 0) + 1 }
  namespace Models
  model :team do
    collection :teammates, model: :teammate, index: :team
  end
  model :teammate do
    index :team
    collection :skills, model: :skill, index: :teammate
    collection :queues, model: :queue, using: :skill, index: [:teammate, :queue]
  end
  model :task do
    index :queue do
      store :tasks_waiting, sorted_by: :queued_at, if: ->(task) { task.status == "queued" }
      store :tasks_offered,                        if: ->(task) { task.status == "offered" }
    end
  end
  model :queue, class: TaskQueue do
    sorted_collection :tasks_waiting, model: :task, index: {:queue => :tasks_waiting}
    collection :tasks_offered,        model: :task, index: {:queue => :tasks_offered}
    collection :skills, model: :skill, index: :queue
    collection :teammates, model: :teammate, using: :skill, index: [:queue, :teammate]
  end
  model :skill do
    index :queue, inline_reference: true
    index :teammate, inline_reference: true
  end
end

feature "persisting models" do
  let(:accessor) { PersistentAccessor.new(redis_config) }

  scenario "write, reload and erase a model" do
    queue = TaskQueue.new(name: "fix bugs")
    accessor.write(queue)
    expect(queue.num_saved).to eq(1)
    accessor.write(queue)
    expect(queue.num_saved).to eq(2)

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
    team = Team.new(name: "engineering")
    teammate = Teammate.new(name: "John Doe", team: team)
    other = Teammate.new(name: "Jane Doe", team: team)
    accessor.write(teammate, other)
    reloaded_team = accessor.read(:team, teammate.team.uid)

    collection = accessor.collection(reloaded_team, :teammates)
    expect(collection.count).to eq(2)
    expect(collection.all.map(&:name).sort).to eq(["Jane Doe", "John Doe"])
  end

  scenario "query a model's referrers via another model" do
    teammate = Teammate.new(name: "John Doe", team: Team.new(name: "Anonymous"))
    bugs = TaskQueue.new(name: "fix bugs")
    specs = TaskQueue.new(name: "write specs")
    enhancements = TaskQueue.new(name: "enhancements")
    accessor.write(
      Skill.new(teammate: teammate, task_queue: bugs, level: 50),
      Skill.new(teammate: teammate, task_queue: enhancements, level: 50)
    )

    collection = accessor.collection(teammate, :task_queues)
    expect(collection.count).to eq(2)
    expect(collection.all.map(&:name).sort).to eq(["enhancements", "fix bugs"])
  end

  scenario "query a model's sorted collection" do
    queue = TaskQueue.new(name: "fix bugs")
    def queue.add_task(task)
      task.queued_at = Time.now
      task.task_queue = self
    end
    task1 = Task.new(title: "bug #123")
    task2 = Task.new(title: "bug #456")

    queue.add_task(task2)
    queue.add_task(task1)
    accessor.write(queue, task1, task2)

    queue = accessor.read(:task_queue, queue.uid)
    collection = accessor.collection(queue, :tasks)
    expect(collection.count).to eq(2)
    expect(collection.first_uid).to eq(task2.uid)
  end
end
