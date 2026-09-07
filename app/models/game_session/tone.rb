class GameSession::Tone < Data.define(:key, :label, :directive)
  extend Catalog

  ALL = [
    new(key: "fun", label: "Eğlenceli",
        directive: "Eğlenceli — tempo hafif, mizah durumlardan ve diyalogdan doğar, sahne başına bir iki espri yeter ve gerilim yükselse de sürer (dorukta ve finalde bile bir kuru replik bulunur); dünya yine de gerçektir, tehlike ciddiye alınır, parodiye kaçılmaz."),
    new(key: "balanced", label: "Dengeli",
        directive: "Dengeli — klasik macera: umut ile tehlike dengede, zaferin tadı bedeliyle gelir."),
    new(key: "dark", label: "Karanlık",
        directive: "Karanlık — gölgeler ağır basar, bedeller serttir, güven zor kazanılır; korku PEGI-12 sınırında kalır.")
  ].freeze
end
