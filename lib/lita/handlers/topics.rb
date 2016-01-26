require 'yaml'
module Lita
  module Handlers
    class Topics < Handler
      APPENDED = "appended"
      BASE = "base"
      SEPARATOR = "separator"

      on :loaded, :define_routes
      on :appended_topic_position, :appended_topic_position
      # insert handler code here

      Lita.register_handler(self)
      def define_routes(payload)
        self.class.route(/^topic base (.*?)$/, :set_base_topic, command: true)
        self.class.route(/^topic reset$/, :reset_topic, command: true)
        self.class.route(/^topic set (.*?)$/, :set_appended_topic, command: true)
        self.class.route(/^topic (\d+) set (.*?)$/, :set_appended_topic_position, command: true)
        self.class.route(/^topic append (.*?)$/, :append_topic, command: true)
        self.class.route(/^topic separator (.*?)$/, :set_topic_separator, command: true)
        self.class.route(/^debug$/, :listen, command: true)
      end

      def listen(response)
        byebug
      end

      def append_topic response
        appended = get_appended(response.room)
        appended << response.matches[0][0]
        set_appended response.room, appended
        update_topic response.room
      end

      def reset_topic response
        set_appended response.room, []
        update_topic response.room
      end

      def set_appended_topic response
        set_appended response.room, [response.matches[0][0]]
        update_topic response.room
      end

      def set_appended_topic_position response
        robot.trigger :appended_topic_position, room: response.room, topic: response.matches[0][1], position: response.matches[0][0]
      end

      def appended_topic_position payload
        appended = get_appended payload[:room]
        appended[payload[:position].to_i] = payload[:topic] if payload[:position] != nil
        appended << payload[:topic] unless payload[:position] != nil
        set_appended payload[:room], appended
        update_topic payload[:room]
      end

      def set_base_topic response
        redis.set full_key(response.room, BASE), response.matches[0][0]
        update_topic response.room
      end

      def set_topic_separator response
        redis.set full_key(response.room, SEPARATOR), response.matches[0][0]
        update_topic response.room
      end

      private

      def set_topic room, topic
        robot.set_topic Source.new(room: room), topic
      end

      def full_key room, key
        "lita-topics:#{room.id}:#{key}"
      end

      def set_appended room, appended
        redis.set full_key(room, APPENDED), Marshal.dump(appended)
      end

      def get_appended room
        value = redis.get full_key(room, APPENDED)

        begin
          Marshal.load value
        rescue
          []
        end
      end

      def update_topic room
        base = redis.get full_key(room, BASE)
        appended = get_appended(room)
        separator = redis.get full_key(room, SEPARATOR)
        set_topic room, [base].concat(appended).join(" #{separator} ")
      end
    end
  end
end
