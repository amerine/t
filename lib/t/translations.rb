require 'i18n'

module T
  module Translations
    I18n.load_path = Dir[File.expand_path(File.join("..", "locales", "*.yml"), __FILE__)]
    I18n.locale = :en
  end
end
