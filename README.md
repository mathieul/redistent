# Redistent

<div style="color: red; font-weight: bold;">WORK IN PROGRESS: this gem is neither code complete, neither usable at the moment.</div>

[![Build Status](https://secure.travis-ci.org/mathieul/redistent.png)](http://travis-ci.org/mathieul/redistent)
[![Dependency Status](https://gemnasium.com/mathieul/redistent.png)](https://gemnasium.com/mathieul/redistent)
[![Code Climate](https://codeclimate.com/github/mathieul/redistent.png)](https://codeclimate.com/github/mathieul/redistent)
[![Coverage Status](https://coveralls.io/repos/mathieul/redistent/badge.png?branch=master)](https://coveralls.io/r/mathieul/redistent)


Light persistent layer for Ruby objects using Redis and a centralized persister object.

## Installation

Add this line to your application's Gemfile:

    gem 'redistent'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redistent

## Usage

```ruby
class TaskQueue
  include Virtus
  attr_reader :id
  attribute :name, String
end

class Task
  include Virtus
  attr_reader :id
  attribute :title, String
  attribute :queue, TaskQueue
  attribute :queued_at, DateTime
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

accessor = PersistentAccessor.new(url: "redis://127.0.0.1:6379/7")

# write/read/erase
bug_queue = TaskQueue.new(name: "fix bugs")
accessor.write(bug_queue)
feature_queue = accessor.read(:queue, "id123")
accessor.erase(bug_queue)

# collection of referrers
skill_collection = accessor.collection(feature_queue, :skills)
num_skills = skill_collection.count
all_skills = skill_collection.all

# collection of indirect referrers
all_teammates = accessor.collection(feature_queue, :teammates).all

# collection of embedded objects
task_collection = accessor.collection(feature_queue, :tasks)
task_collection << Task.new(title: "generate csv report")
next_task_id = task_collection.next_id
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
