module Redistent
  class Collection
    include HasModelKeys

    attr_reader :accessor, :model, :description

    def initialize(accessor, model, description)
      @accessor    = accessor
      @model       = model
      @description = description
      add_abilities(description.type)
    end

    private

    def add_abilities(type)
      case type
      when :referenced
        extend(ReferencedAbilities)
      when :indirect
        extend(IndirectAbilities)
      when :sorted
        extend(SortedAbilities)
      end
    end

    def key
      accessor.key
    end

    def collection_key
      @collection_key ||= index_key(description.model, description.attribute)[model.uid]
    end

    module ReferencedAbilities
      def count
        accessor.with_lock { collection_key.scard }
      end

      def uids
        accessor.with_lock { collection_key.smembers }
      end

      def all
        uids.map { |uid| accessor.read(description.model, uid) }
      end
    end

    module IndirectAbilities
      def count
        uids.length
      end

      def uids
        accessor.with_lock {
          collection_key.sort(
            by: "nosort",
            get: reference_keys(description.model, description.target_attribute)
          )
        }
      end

      def all
        uids.map { |uid| accessor.read(description.target, uid) }
      end
    end

    module SortedAbilities
      def count
        accessor.with_lock { collection_key.zcard }
      end

      def uids
        accessor.with_lock { collection_key.zrange(0, -1) }
      end

      def first_uid
        accessor.with_lock {
          collection_key.zrangebyscore("-inf", "+inf", limit: [0, 1]).first
        }
      end

      def last_uid
        accessor.with_lock {
          collection_key.zrevrangebyscore("+inf", "-inf", limit: [0, 1]).first
        }
      end

      def all
        uids.map { |uid| accessor.read(description.model, uid) }
      end

      def first
        read(first_uid)
      end

      def last
        read(last_uid)
      end

      private

      def collection_key
        @collection_key ||= sorted_key(description.reference.model, model.uid, description.attribute)
      end

      def read(uid)
        uid ? accessor.read(description.model, uid) : nil
      end
    end
  end
end
