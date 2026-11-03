class GameSession::Trouble < Data.define(:key)
  extend Catalog

  translates :text

  ALL = %w[ missing_child dry_well riders_coming stolen_seal broken_oath called_debt sleeping_sickness silent_bell ].map { |key| new(key: key) }.freeze
end
