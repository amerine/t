require 'thor'

module T
  autoload :RCFile, 't/rcfile'
  autoload :Requestable, 't/requestable'
  class Set < Thor
    include T::Requestable

    check_unknown_options!

    def initialize(*)
      super
      @rcfile = RCFile.instance
    end

    desc "active SCREEN_NAME [CONSUMER_KEY]", I18n.t("tasks.set.active.desc")
    def active(screen_name, consumer_key=nil)
      require 't/core_ext/string'
      screen_name = screen_name.strip_ats
      @rcfile.path = options['profile'] if options['profile']
      consumer_key = @rcfile[screen_name].keys.last if consumer_key.nil?
      @rcfile.active_profile = {'username' => screen_name, 'consumer_key' => consumer_key}
      say I18n.t("tasks.set.active.success")
    end
    map %w(default) => :active

    desc "bio DESCRIPTION", I18n.t("tasks.set.bio.desc")
    def bio(description)
      client.update_profile(:description => description)
      say I18n.t("tasks.set.bio.success", :profile => @rcfile.active_profile[0])
    end

    desc "language LANGUAGE_NAME", I18n.t("tasks.set.language.desc")
    def language(language_name)
      client.settings(:lang => language_name)
      say I18n.t("tasks.set.language.success", :profile => @rcfile.active_profile[0])
    end

    desc "location PLACE_NAME", I18n.t("tasks.set.location.desc")
    def location(place_name)
      client.update_profile(:location => place_name)
      say I18n.t("tasks.set.location.success", :profile => @rcfile.active_profile[0])
    end

    desc "name NAME", I18n.t("tasks.set.name.desc")
    def name(name)
      client.update_profile(:name => name)
      say I18n.t("tasks.set.name.success", :profile => @rcfile.active_profile[0])
    end

    desc "url URL", I18n.t("tasks.set.url.desc")
    def url(url)
      client.update_profile(:url => url)
      say I18n.t("tasks.set.url.success", :profile => @rcfile.active_profile[0])
    end

  end
end
