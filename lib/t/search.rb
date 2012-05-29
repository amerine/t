require 'thor'
require 'twitter'

module T
  autoload :Collectable, 't/collectable'
  autoload :Printable, 't/printable'
  autoload :RCFile, 't/rcfile'
  autoload :Requestable, 't/requestable'
  autoload :Translations, 't/translations'
  class Search < Thor
    include T::Collectable
    include T::Printable
    include T::Requestable
    include T::Translations

    DEFAULT_NUM_RESULTS = 20
    MAX_NUM_RESULTS = 200
    MAX_USERS_PER_REQUEST = 20

    check_unknown_options!

    def initialize(*)
      super
      @rcfile = RCFile.instance
    end

    desc "all QUERY", I18n.t("tasks.search.all.desc", :default_num => DEFAULT_NUM_RESULTS)
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    method_option "number", :aliases => "-n", :type => :numeric, :default => DEFAULT_NUM_RESULTS
    def all(query)
      rpp = options['number'] || DEFAULT_NUM_RESULTS
      statuses = collect_with_rpp(rpp) do |opts|
        client.search(query, opts)
      end
      require 'htmlentities'
      if options['csv']
        require 'csv'
        require 'fastercsv' unless Array.new.respond_to?(:to_csv)
        say STATUS_HEADINGS.to_csv unless statuses.empty?
        statuses.each do |status|
          say [status.id, csv_formatted_time(status), status.from_user, HTMLEntities.new.decode(status.full_text)].to_csv
        end
      elsif options['long']
        array = statuses.map do |status|
          [status.id, ls_formatted_time(status), "@#{status.from_user}", HTMLEntities.new.decode(status.full_text).gsub(/\n+/, ' ')]
        end
        format = options['format'] || STATUS_HEADINGS.size.times.map{"%s"}
        print_table_with_headings(array, STATUS_HEADINGS, format)
      else
        say unless statuses.empty?
        statuses.each do |status|
          print_message(status.from_user, status.full_text)
        end
      end
    end

    desc "favorites QUERY", I18n.t("tasks.search.favorites.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    def favorites(query)
      opts = {:count => MAX_NUM_RESULTS}
      statuses = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        client.favorites(opts)
      end
      statuses = statuses.select do |status|
        /#{query}/i.match(status.full_text)
      end
      print_statuses(statuses)
    end
    map %w(faves) => :favorites

    desc "list [USER/]LIST QUERY", I18n.t("tasks.search.list.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.common_options.id")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc =>  I18n.t("tasks.common_options.long")
    def list(list, query)
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
      opts = {:count => MAX_NUM_RESULTS}
      statuses = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        client.list_timeline(owner, list, opts)
      end
      statuses = statuses.select do |status|
        /#{query}/i.match(status.full_text)
      end
      print_statuses(statuses)
    end

    desc "mentions QUERY", I18n.t("tasks.search.mentions.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    def mentions(query)
      opts = {:count => MAX_NUM_RESULTS}
      statuses = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        client.mentions(opts)
      end
      statuses = statuses.select do |status|
        /#{query}/i.match(status.full_text)
      end
      print_statuses(statuses)
    end
    map %w(replies) => :mentions

    desc "retweets QUERY", I18n.t("tasks.search.retweets.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    def retweets(query)
      opts = {:count => MAX_NUM_RESULTS}
      statuses = collect_with_max_id do |max_id|
        opts[:max_id] = max_id unless max_id.nil?
        client.retweeted_by(opts)
      end
      statuses = statuses.select do |status|
        /#{query}/i.match(status.full_text)
      end
      print_statuses(statuses)
    end
    map %w(rts) => :retweets

    desc "timeline [USER] QUERY", I18n.t("tasks.search.timeline.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "id", :aliases => "-i", :type => "boolean", :default => false, :desc => I18n.t("tasks.common_options.id")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    def timeline(*args)
      opts = {:count => MAX_NUM_RESULTS}
      query = args.pop
      user = args.pop
      if user
        require 't/core_ext/string'
        user = if options['id']
          user.to_i
        else
          user.strip_ats
        end
        statuses = collect_with_max_id do |max_id|
          opts[:max_id] = max_id unless max_id.nil?
          client.user_timeline(user, opts)
        end
      else
        statuses = collect_with_max_id do |max_id|
          opts[:max_id] = max_id unless max_id.nil?
          client.home_timeline(opts)
        end
      end
      statuses = statuses.select do |status|
        /#{query}/i.match(status.full_text)
      end
      print_statuses(statuses)
    end
    map %w(tl) => :timeline

    desc "users QUERY", I18n.t("tasks.search.users.desc")
    method_option "csv", :aliases => "-c", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.csv")
    method_option "favorites", :aliases => "-v", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.favorites")
    method_option "followers", :aliases => "-f", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.followers")
    method_option "friends", :aliases => "-e", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.friends")
    method_option "listed", :aliases => "-d", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.listed")
    method_option "long", :aliases => "-l", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.long")
    method_option "posted", :aliases => "-p", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.posted")
    method_option "reverse", :aliases => "-r", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.reverse")
    method_option "tweets", :aliases => "-t", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.tweets")
    method_option "unsorted", :aliases => "-u", :type => :boolean, :default => false, :desc => I18n.t("tasks.common_options.sorts.unsorted")
    def users(query)
      require 't/core_ext/enumerable'
      require 'retryable'
      users = 1.upto(50).threaded_map do |page|
        retryable(:tries => 3, :on => Twitter::Error::ServerError, :sleep => 0) do
          client.user_search(query, :page => page, :per_page => MAX_USERS_PER_REQUEST)
        end
      end.flatten
      print_users(users)
    end

  end
end
