class GameSession::Place < Data.define(:key, :troubles, :figures)
  extend Catalog

  translates :text

  ALL = {
    fishing_village: [
      %w[ missing_child dry_well riders_coming called_debt sleeping_sickness missing_healer beast_returns stolen_stores
          broken_wedding witch_bargain lost_messenger false_accusation ],
      %w[ weather_reader path_child old_captain weary_smuggler doubted_healer selling_innkeeper lonely_moneylender gravedigger ]
    ],
    mining_town: [
      %w[ missing_child dry_well called_debt sleeping_sickness missing_healer dark_wards beast_returns stolen_stores
          empty_strongbox false_accusation rival_claim cut_off ],
      %w[ indebted_smith young_guard ambitious_clerk lonely_moneylender doubted_healer selling_innkeeper gravedigger
          path_child greedy_bridgekeeper ]
    ],
    river_ferry: [
      %w[ missing_child riders_coming called_debt beast_returns kidnapped broken_wedding lost_messenger false_accusation
          rival_claim cut_off ],
      %w[ greedy_bridgekeeper weary_smuggler selling_innkeeper path_child old_captain young_guard weather_reader ]
    ],
    steppe_camp: [
      %w[ missing_child dry_well riders_coming broken_oath sleeping_sickness missing_healer dead_fire beast_returns
          kidnapped stolen_stores broken_wedding witch_bargain rival_claim ],
      %w[ weather_reader path_child stable_hand unwilling_heir doubted_healer unknown_bard exiled_noble ]
    ],
    charcoal_camp: [
      %w[ missing_child called_debt sleeping_sickness dead_fire dark_wards beast_returns kidnapped witch_bargain
          false_accusation rival_claim cut_off ],
      %w[ path_child hermit weary_smuggler weather_reader doubted_healer hiding_apprentice unwilling_heir ]
    ],
    border_fort: [
      %w[ riders_coming stolen_seal broken_oath sleeping_sickness missing_healer kidnapped stolen_stores empty_strongbox
          lost_messenger false_accusation rival_claim cut_off ],
      %w[ young_guard old_captain stable_hand ambitious_clerk exiled_noble doubted_healer weary_smuggler unknown_bard
          indebted_smith greedy_bridgekeeper ]
    ],
    city_docks: [
      %w[ missing_child stolen_seal called_debt sleeping_sickness kidnapped stolen_stores broken_wedding empty_strongbox
          witch_bargain lost_messenger false_accusation rival_claim ],
      %w[ weary_smuggler lonely_moneylender old_captain ambitious_clerk path_child selling_innkeeper young_guard
          exiled_noble unknown_bard indebted_smith ]
    ],
    salt_caves: [
      %w[ missing_child dry_well called_debt sleeping_sickness dark_wards beast_returns kidnapped witch_bargain
          lost_messenger false_accusation rival_claim cut_off ],
      %w[ hermit path_child weary_smuggler ambitious_clerk hiding_apprentice doubted_healer ]
    ],
    lighthouse_rock: [
      %w[ dry_well sleeping_sickness missing_healer dead_fire dark_wards beast_returns stolen_stores witch_bargain
          lost_messenger false_accusation cut_off ],
      %w[ weather_reader old_captain hermit weary_smuggler unwilling_heir ]
    ],
    merchant_ship: [
      %w[ dry_well called_debt sleeping_sickness missing_healer beast_returns kidnapped empty_strongbox witch_bargain
          false_accusation ],
      %w[ old_captain weary_smuggler lonely_moneylender ambitious_clerk exiled_noble doubted_healer unknown_bard
          weather_reader ]
    ],
    snowbound_pass: [
      %w[ missing_child riders_coming stolen_seal sleeping_sickness missing_healer dead_fire beast_returns kidnapped
          stolen_stores lost_messenger false_accusation cut_off ],
      %w[ selling_innkeeper weather_reader young_guard path_child exiled_noble weary_smuggler stable_hand doubted_healer
          unknown_bard ]
    ],
    cliff_monastery: [
      %w[ missing_child stolen_seal broken_oath sleeping_sickness missing_healer dead_fire dark_wards kidnapped
          witch_bargain lost_messenger false_accusation cut_off ],
      %w[ doubting_novice hermit hiding_apprentice doubted_healer ambitious_clerk exiled_noble unwilling_heir path_child
          gravedigger ]
    ],
    stilt_village: [
      %w[ missing_child dry_well riders_coming sleeping_sickness missing_healer dead_fire beast_returns stolen_stores
          broken_wedding witch_bargain false_accusation rival_claim ],
      %w[ path_child weather_reader doubted_healer weary_smuggler hermit unwilling_heir gravedigger unknown_bard ]
    ],
    desert_caravanserai: [
      %w[ dry_well riders_coming stolen_seal called_debt sleeping_sickness kidnapped broken_wedding empty_strongbox
          lost_messenger false_accusation rival_claim cut_off ],
      %w[ selling_innkeeper lonely_moneylender weary_smuggler stable_hand path_child unknown_bard exiled_noble
          weather_reader ambitious_clerk ]
    ],
    buried_tunnels: [
      %w[ missing_child sleeping_sickness dark_wards beast_returns kidnapped stolen_stores witch_bargain lost_messenger
          false_accusation rival_claim cut_off ],
      %w[ path_child weary_smuggler hiding_apprentice hermit gravedigger exiled_noble last_of_the_house ]
    ],
    tanners_quarter: [
      %w[ missing_child dry_well called_debt sleeping_sickness missing_healer dead_fire kidnapped stolen_stores
          broken_wedding empty_strongbox false_accusation rival_claim ],
      %w[ unwilling_heir lonely_moneylender indebted_smith ambitious_clerk path_child doubted_healer gravedigger
          unknown_bard last_of_the_house young_guard ]
    ],
    keep_kitchens: [
      %w[ missing_child dry_well riders_coming stolen_seal broken_oath sleeping_sickness dead_fire kidnapped
          stolen_stores broken_wedding empty_strongbox witch_bargain false_accusation ],
      %w[ stable_hand young_guard ambitious_clerk unwilling_heir unknown_bard doubted_healer hiding_apprentice path_child ]
    ],
    frozen_lake_lodge: [
      %w[ missing_child sleeping_sickness missing_healer dead_fire dark_wards beast_returns kidnapped stolen_stores
          witch_bargain lost_messenger false_accusation cut_off ],
      %w[ hermit weather_reader path_child exiled_noble unwilling_heir weary_smuggler doubted_healer ]
    ],
    prison_island: [
      %w[ dry_well broken_oath sleeping_sickness missing_healer dark_wards kidnapped stolen_stores lost_messenger
          false_accusation cut_off ],
      %w[ young_guard exiled_noble weary_smuggler old_captain doubted_healer gravedigger doubting_novice ambitious_clerk ]
    ],
    burial_mounds: [
      %w[ missing_child riders_coming broken_oath sleeping_sickness dead_fire dark_wards beast_returns kidnapped
          witch_bargain lost_messenger rival_claim ],
      %w[ gravedigger hermit weather_reader last_of_the_house unwilling_heir path_child unknown_bard exiled_noble ]
    ]
  }.map { |key, (troubles, figures)| new(key: key.to_s, troubles: troubles, figures: figures) }.freeze
end
