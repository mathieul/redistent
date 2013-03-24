# Redistent

[![Build Status](https://secure.travis-ci.org/mathieul/redistent.png)](http://travis-ci.org/mathieul/redistent)
[![Dependency Status](https://gemnasium.com/mathieul/redistent.png)](https://gemnasium.com/mathieul/redistent)
[![Code Climate](https://codeclimate.com/github/mathieul/redistent.png)](https://codeclimate.com/github/mathieul/redistent)

Light persistent layer for Ruby objects using Redis and a centralized persister object.

## Installation

Add this line to your application's Gemfile:

    gem 'redistent'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redistent

## Usage

    class Queue
      include Virtus
      attribute :name, String
      embeds :tasks, score: ->(task) { task.created_ts } do
        # key = "Queue:123:task_ids"
        define(:count)   { |key| key.zcard }
        define(:next_id) { |key| key.command(...read next id...) }
      end
    end

    class Teammate
    end

    class Task
    end

    class Skill
      references :teammate do
        # key = "Skill:indices:teammate_id"
        save { |model, key|
          # "#{key}:old123": srem model.id
          # "#{key}:new456": sadd model.id
        }
        del { |model, key| # "#{key}:id789": srem model.id }
      end
      references :queue
    end

    queue = Queue.new(name)

    store.save(queue, task)
    store.get(:queue, queue_id) # any reference is instantiated?
    store.delete(task)
    store.referenced_by(queue).skills.all
    store.embedded_in(queue).tasks << task
    store.embedded_in(queue).tasks.count
    store.embedded_in(queue).tasks.next_id

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
