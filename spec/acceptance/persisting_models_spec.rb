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
  attribute :queued_at, Time
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
  model :task do
    references :task_queue
  end
  model :task_queue do
    collection :tasks, sort_by: :queued_at
    collection :teammates, via: :skills
  end
  model :skill do
    references :task_queue
    references :teammate
  end

  # model :team do
  #   collection :teammates # using: ns:Teammate:indices:team_uid:<team_uid>
  # end

  # model :teammate do
  #   # ns:Teammate:<uid>                   => STRING <attributes>[serialized with ref uids]
  #   # ns:Teammate:<uid>:team              => STRING <team.uid>
  #   # ns:Teammate:indices:team:<team.uid> => SET <uid>

  #   collection :task_queues # using: ns:Skill:indices:teammate:<uid> and ns:Skill:<skill_uid>:task_queue
  # end

  # model :task do
  #   # ns:Task:<uid>                               => STRING <attributes>[serialized with ref uids]
  #   # ns:Task:<uid>:task_queue                    => STRING <task_queue.uid>
  #   # ns:Task:indices:task_queue:<task_queue.uid> => SET <uid>
  # end

  # model :task_queue do
  #   # ns:TaskQueue:<uid>                       => STRING <attributes>[serialized with ref uids]
  #   # ns:TaskQueue:<uid>:tasks_waiting         => ZSET <task.uid SCORE task.queued_at>
  #   # ns:TaskQueue:<uid>:indices:tasks_offered => SET <task.uid>

  #   collection :tasks_waiting # using: ns:TaskQueue:<uid>:tasks_waiting
  #   collection :tasks_offered # using: ns:TaskQueue:<uid>:indices:tasks_offered
  #   collection :teammates # using: ns:Skill:indices:task_queue:<uid> and ns:Skill:<skill_uid>:teammate
  # end

  # model :skill do
  #   # ns:Skill:<uid>                               => STRING <attributes>[serialized with ref uids]
  #   # ns:Skill:<uid>:task_queue                    => STRING <task_queue.uid>
  #   # ns:Skill:indices:task_queue:<task_queue.uid> => SET <uid>
  #   # ns:Skill:<uid>:teammate                      => STRING <teammate.uid>
  #   # ns:Skill:indices:teammate:<teammate.uid>     => SET <uid>
  # end
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
