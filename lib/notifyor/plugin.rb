require 'active_support'
require 'redis'

module Notifyor
  module Plugin
    extend ::ActiveSupport::Concern

    included do
    end

    module ClassMethods
      def notifyor(options = {})
        configure_plugin(options)
      end

      def configure_plugin(options = {})
        configuration = default_configuration.deep_merge(options)
        publish_channels = configuration[:channels] || ['notifyor']
        append_callbacks(configuration, publish_channels)
      end

      def append_callbacks(configuration, publish_channels)
        publish_channels.each do |channel|
          configuration[:only].each do |action|
            case action
              when :create
                self.after_commit -> { ::Notifyor.configuration.redis_connection.publish_channel, configuration[:messages][:create].call(self) }, on: :create, if: -> { configuration[:only].include? :create }
              when :update
                self.after_commit -> { ::Notifyor.configuration.redis_connection.publish_channel, configuration[:messages][:update].call(self) }, on: :update, if: -> { configuration[:only].include? :update }
              when :destroy
                self.before_destroy -> { ::Notifyor.configuration.redis_connection.publish_channel, configuration[:messages][:destroy].call(self) }, if: -> { configuration[:only].include? :destroy }
              else
                #nop
            end
          end
        end
      end

      def default_configuration
        {
            only: [:create, :destroy, :update],
            messages: {
                create: -> (model) { I18n.t('notifyor.model.create') },
                update: -> (model) { I18n.t('notifyor.model.update') },
                destroy: -> (model) { I18n.t('notifyor.model.destroy') }
            }
        }
      end

    end
  end
end
