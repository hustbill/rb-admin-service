require "#{Goliath.root}/lib/string"

# I18n.default_locale  is set in client_theme in this directory
LANGUAGES = [
  ['English', 'en'],
  ["Español".html_safe, 'es'],
  ["Czech".html_safe, 'cz'],
  ['Deutsch', 'de'],
  ["Français".html_safe, 'fr'],
  ["Ελληνικά".html_safe, 'gr'],
  ["Hungarian".html_safe, 'hu'],
  ["Italiano".html_safe, 'it'],
  ["日本語".html_safe, 'jp'],
  ["Nederlands".html_safe, 'nl'],
  ["Polski".html_safe, 'pl'],
  ["русский язык".html_safe, 'ru'],
  ["Slovenščina".html_safe, 'si'],
  ["ภาษาไทย".html_safe, 'th'],
  ["中文(繁體)".html_safe, 'tw']
]
COUNTRIES =
 [["Singapore", "SG"], ["Kenya", "KE"], ["Kazakhstan", "KZ"], ["New Zealand", "NZ"], ["Australia", "AU"], ["Dominican Republic", "DO"], ["Ecuador", "EC"], ["Belgium", "BE"], ["Philippines", "PH"], ["Jamaica", "JM"], ["Ireland", "IE"], ["Italy", "IT"], ["Thailand", "TH"], ["Austria", "AT"], ["Cyprus", "CY"], ["Germany", "DE"], ["Greece", "GR"], ["Netherlands", "NL"], ["Spain", "ES"], ["United Kingdom", "GB"], ["Taiwan", "TW"], ["Mexico", "MX"], ["United States", "US"], ["Canada", "CA"], ["Peru", "PE"], ["Malaysia (West)", "MY"], ["Poland", "PL"], ["Hungary", "HU"], ["Japan", "JP"], ["Malaysia (East)", "M1"], ["Russian Federation", "RU"], ["Ukraine", "UA"], ["France", "FR"], ["Slovenia", "SI"], ["Czech Republic", "CZ"]]

module I18n
  module Backend
    class KeyValue
      def available_locales
        a = [:en]
        LANGUAGES.each do |l|
          COUNTRIES.each do |c|
            a << "#{l[1]}-#{c[1]}".to_sym
          end
        end
        a
      end
    end
  end
end
