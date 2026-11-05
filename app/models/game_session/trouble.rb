class GameSession::Trouble < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[
    missing_child dry_well riders_coming stolen_seal broken_truce called_debt fever
    missing_healer unlit_beacon set_fire beast_returns kidnapped stolen_stores broken_wedding
    empty_strongbox witch_bargain lost_messenger false_accusation rival_claim cut_off
  ].map { |key| new(key: key) }.freeze
end
