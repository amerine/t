require 'thor'
require 'twitter'

module T
  autoload :RCFile, 't/rcfile'
  autoload :Requestable, 't/requestable'
  autoload :Translations, 't/translations'
  class Delete < Thor
    include T::Requestable
    include T::Translations

    check_unknown_options!

    def initialize(*)
      super
      @rcfile = RCFile.instance
    end

    desc "block USER [USER...]", I18n.t("tasks.delete.block.desc")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.delete.block.id")
    method_option "force", :aliases => "-f", :type => :boolean, :default => false
    def block(user, *users)
      users.unshift(user)
      require 't/core_ext/string'
      if options['id']
        users.map!(&:to_i)
      else
        users.map!(&:strip_ats)
      end
      require 't/core_ext/enumerable'
      require 'retryable'
      users = users.threaded_map do |user|
        retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
          client.unblock(user)
        end
      end
      number = users.length
      say I18n.t("tasks.delete.block.unblocked", :profile => @rcfile.active_profile[0], :count => number)
      say
      say I18n.t("tasks.delete.block.block-instructions",
                 :command_name => File.basename($0),
                 :users => users.map{|user| "@#{user.screen_name}"}.join(' '))
    end

    desc "dm [DIRECT_MESSAGE_ID] [DIRECT_MESSAGE_ID...]", I18n.t("tasks.delete.dm.desc")
    method_option "force", :aliases => "-f", :type => :boolean, :default => false
    def dm(direct_message_id, *direct_message_ids)
      direct_message_ids.unshift(direct_message_id)
      require 't/core_ext/string'
      direct_message_ids.map!(&:to_i)
      direct_message_ids.each do |direct_message_id|
        unless options['force']
          direct_message = client.direct_message(direct_message_id)
          return unless yes? I18n.t("tasks.delete.dm.confirm", :recipient => direct_message.recipient.screen_name, :message_text => direct_message.text)
        end
        direct_message = client.direct_message_destroy(direct_message_id)
        say I18n.t("tasks.delete.dm.deleted",
                   :profile => @rcfile.active_profile[0],
                   :recipient => direct_message.recipient.screen_name,
                   :message_text => direct_message.text)
      end
    end
    map %w(d m) => :dm

    desc "favorite STATUS_ID [STATUS_ID...]", I18n.t("tasks.delete.favorite.desc")
    method_option "force", :aliases => "-f", :type => :boolean, :default => false
    def favorite(status_id, *status_ids)
      status_ids.unshift(status_id)
      require 't/core_ext/string'
      status_ids.map!(&:to_i)
      status_ids.each do |status_id|
        unless options['force']
          status = client.status(status_id, :include_my_retweet => false, :trim_user => true)
          return unless yes? I18n.t("tasks.delete.favorite.confirm",
                                    :from_user => status.from_user,
                                    :full_text => status.full_text)
        end
        status = client.unfavorite(status_id)
        say I18n.t("tasks.delete.favorite.deleted",
                   :profile => @rcfile.active_profile[0],
                   :from_user => status.from_user,
                   :full_text => status.full_text)
      end
    end
    map %w(fave favourite) => :favorite

    desc "list LIST", I18n.t("tasks.delete.list.desc")
    method_option "force", :aliases => "-f", :type => :boolean, :default => false
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.delete.list.id")
    def list(list)
      if options['id']
        require 't/core_ext/string'
        list = list.to_i
      end
      list = client.list(list)
      unless options['force']
        return unless yes? I18n.t("tasks.delete.list.confirm", :list_name => list.name)
      end
      client.list_destroy(list)
      say I18n.t("tasks.delete.list.deleted",
                 :profile => @rcfile.active_profile[0],
                 :list_name => list.name)
    end

    desc "status STATUS_ID [STATUS_ID...]", I18n.t('tasks.delete.status.desc')
    method_option "force", :aliases => "-f", :type => :boolean, :default => false
    def status(status_id, *status_ids)
      status_ids.unshift(status_id)
      require 't/core_ext/string'
      status_ids.map!(&:to_i)
      status_ids.each do |status_id|
        unless options['force']
          status = client.status(status_id, :include_my_retweet => false, :trim_user => true)
          return unless yes? I18n.t("tasks.delete.status.confirm",
                                    :from_user => status.from_user,
                                    :full_text => status.full_text)
        end
        status = client.status_destroy(status_id, :trim_user => true)
        say I18n.t("tasks.delete.status.deleted",
                   :profile => @rcfile.active_profile[0],
                   :full_text => status.full_text)
      end
    end
    map %w(post tweet update) => :status

  end
end
