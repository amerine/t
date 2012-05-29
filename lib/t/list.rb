require 'thor'
require 'twitter'

module T
  autoload :Collectable, 't/collectable'
  autoload :FormatHelpers, 't/format_helpers'
  autoload :Printable, 't/printable'
  autoload :RCFile, 't/rcfile'
  autoload :Requestable, 't/requestable'
  autoload :Translations, 't/translations'
  class List < Thor
    include T::Collectable
    include T::Printable
    include T::Requestable
    include T::FormatHelpers
    include T::Translations

    DEFAULT_NUM_RESULTS = 20
    MAX_USERS_PER_LIST = 500
    MAX_USERS_PER_REQUEST = 100

    check_unknown_options!

    def initialize(*)
      super
      @rcfile = RCFile.instance
    end

    desc "add LIST USER [USER...]", I18n.t("tasks.list.add.desc")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.list.add.id")
    def add(list, user, *users)
      users.unshift(user)
      require 't/core_ext/string'
      if options['id']
        users.map!(&:to_i)
      else
        users.map!(&:strip_ats)
      end
      require 'active_support/core_ext/array/grouping'
      require 't/core_ext/enumerable'
      require 'retryable'
      users.in_groups_of(MAX_USERS_PER_REQUEST, false).threaded_each do |user_id_group|
        retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
          client.list_add_members(list, user_id_group)
        end
      end
      number = users.length
      say I18n.t("tasks.list.add.added", :count => number, :profile => @rcfile.active_profile[0], :list => list)
      say
      if options['id']
        say I18n.t("tasks.list.add.remove-instructions-id",
                   :command_name => File.basename($0),
                   :list => list,
                   :users => users.join(' '))
      else
        say I18n.t("tasks.list.add.removed-instructions",
                   :command_name => File.basename($0),
                   :list => list,
                   :users => users.map{|user| "@#{user}"}.join(' '))
      end
    end

    desc "create LIST [DESCRIPTION]", I18n.t("tasks.list.create.desc")
    method_option "private", :aliases => "-p", :type => :boolean
    def create(list, description=nil)
      opts = description ? {:description => description} : {}
      opts.merge!(:mode => 'private') if options['private']
      client.list_create(list, opts)
      say I18n.t("tasks.list.create.success",
                 :profile => @rcfile.active_profile[0],
                 :list => list)
    end

    desc "information [USER/]LIST", I18n.t("tasks.list.information.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    def information(list)
      owner, list = list.split('/')
      if list.nil?
        list = owner
        owner = @rcfile.active_profile[0]
      else
        require 't/core_ext/string'
        owner = if options['id']
          owner.to_i
        else
          owner.strip_ats
        end
      end
      list = client.list(owner, list)
      if options['csv']
        require 'csv'
        require 'fastercsv' unless Array.new.respond_to?(:to_csv)
        say I18n.t(["list_attrs.id", "list_attrs.description", "list_attrs.slug", "list_attrs.screen-name", "list_attrs.created-at", "list_attrs.members", "list_attrs.subscribers", "list_attrs.following", "list_attrs.mode", "list_attrs.url"]).to_csv
        say [list.id, list.description, list.slug, list.user.screen_name, csv_formatted_time(list), list.member_count, list.subscriber_count, list.following?, list.mode, "https://twitter.com#{list.uri}"].to_csv
      else
        array = []
        array << [I18n.t("list_attrs.id"), list.id.to_s]
        array << [I18n.t("list_attrs.description"), list.description] unless list.description.nil?
        array << [I18n.t("list_attrs.slug"), list.slug]
        array << [I18n.t("list_attrs.screen-name"), "@#{list.user.screen_name}"]
        array << [I18n.t("list_attrs.created-at"), "#{ls_formatted_time(list)} (#{time_ago_in_words(list.created_at)} ago)"]
        array << [I18n.t("list_attrs.members"), number_with_delimiter(list.member_count)]
        array << [I18n.t("list_attrs.subscribers"), number_with_delimiter(list.subscriber_count)]
        array << [I18n.t("list_attrs.status"), list.following ? I18n.t("list_attrs.following") : I18n.t("list_attrs.not-following")]
        array << [I18n.t("list_attrs.mode"), list.mode]
        array << [I18n.t("list_attrs.url"), "https://twitter.com#{list.uri}"]
        print_table(array)
      end
    end
    map %w(details) => :information

    desc "members [USER/]LIST", I18n.t("tasks.list.members.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "favorites", :aliases => "-v", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.favorites")
    method_option "followers", :aliases => "-f", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.followers")
    method_option "friends", :aliases => "-e", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.friends")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.common_options.id")
    method_option "listed", :aliases => "-d", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.listed")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    method_option "posted", :aliases => "-p", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.posted")
    method_option "reverse", :aliases => "-r", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.reverse")
    method_option "tweets", :aliases => "-t", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.tweets")
    method_option "unsorted", :aliases => "-u", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.unsorted")
    def members(list)
      owner, list = list.split('/')
      if list.nil?
        list = owner
        owner = @rcfile.active_profile[0]
      else
        require 't/core_ext/string'
        owner = if options['id']
          owner.to_i
        else
          owner.strip_ats
        end
      end
      users = collect_with_cursor do |cursor|
        client.list_members(owner, list, :cursor => cursor, :skip_status => true)
      end
      print_users(users)
    end

    desc "remove LIST USER [USER...]", I18n.t("tasks.list.remove.desc")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.list.remove.id")
    def remove(list, user, *users)
      users.unshift(user)
      require 't/core_ext/string'
      if options['id']
        users.map!(&:to_i)
      else
        users.map!(&:strip_ats)
      end
      require 'active_support/core_ext/array/grouping'
      require 't/core_ext/enumerable'
      require 'retryable'
      users.in_groups_of(MAX_USERS_PER_REQUEST, false).threaded_each do |user_id_group|
        retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
          client.list_remove_members(list, user_id_group)
        end
      end
      number = users.length
      say I18n.t("tasks.list.remove.success",
                 :profile => @rcfile.active_profile[0],
                 :list => list,
                 :count => number)
      say
      if options['id']
        say I18n.t("tasks.list.remove.add-instructions-id",
                   :command_name => File.basename($0),
                   :list => list,
                   :users => users.join(' '))
      else
        say I18n.t("tasks.list.remove.add-instructions",
                   :command_name => File.basename($0),
                   :list => list,
                   :users => users.map{|user| "@#{user}"}.join(' '))
      end
    end

    desc "timeline [USER/]LIST", I18n.t("tasks.list.timeline.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.common_options.id")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    method_option "number", :aliases => "-n", :type => :numeric, :default => DEFAULT_NUM_RESULTS, :desc => I18n.t("tasks.common_options.number")
    method_option "reverse", :aliases => "-r", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.reverse")
    def timeline(list)
      owner, list = list.split('/')
      if list.nil?
        list = owner
        owner = @rcfile.active_profile[0]
      else
        require 't/core_ext/string'
        owner = if options['id']
          owner.to_i
        else
          owner.strip_ats
        end
      end
      per_page = options['number'] || DEFAULT_NUM_RESULTS
      statuses = collect_with_per_page(per_page) do |opts|
        client.list_timeline(owner, list, opts)
      end
      print_statuses(statuses)
    end
    map %w(tl) => :timeline

  end
end
