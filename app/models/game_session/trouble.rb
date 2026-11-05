class GameSession::Trouble < Data.define(:key, :twists)
  extend Catalog

  translates :text

  ALL = {
    missing_child: %w[ asker_is_cause villain_protects left_willingly no_villain second_chance one_of_two ],
    dry_well: %w[ helper_profits cover_for_worse no_villain old_wrong abandon_place cause_must_help ],
    riders_coming: %w[ old_wrong abandon_place helper_profits friend_opposed one_of_two asker_is_cause ],
    stolen_seal: %w[ asker_is_cause two_culprits outsider_framed cover_for_worse both_hide_same villain_protects ],
    broken_truce: %w[ both_hide_same old_wrong outsider_framed friend_opposed second_chance helper_profits ],
    called_debt: %w[ helper_profits old_wrong villain_protects dear_price second_chance friend_opposed ],
    fever: %w[ dear_price fixer_runs no_villain helper_profits one_of_two second_chance ],
    missing_healer: %w[ left_willingly fixer_runs villain_protects asker_is_cause dear_price one_of_two ],
    unlit_beacon: %w[ no_villain one_of_two second_chance cover_for_worse helper_profits asker_is_cause ],
    set_fire: %w[ outsider_framed two_culprits asker_is_cause old_wrong cover_for_worse villain_protects ],
    beast_returns: %w[ trouble_shields old_wrong no_villain helper_profits cause_must_help abandon_place ],
    kidnapped: %w[ left_willingly asker_is_cause villain_protects one_of_two friend_opposed dear_price ],
    stolen_stores: %w[ no_villain two_culprits outsider_framed helper_profits villain_protects second_chance ],
    broken_wedding: %w[ left_willingly both_hide_same old_wrong villain_protects friend_opposed break_the_rule ],
    empty_strongbox: %w[ no_villain two_culprits outsider_framed cover_for_worse second_chance asker_is_cause ],
    witch_bargain: %w[ dear_price old_wrong villain_protects break_the_rule cause_must_help friend_opposed ],
    lost_messenger: %w[ left_willingly villain_protects cover_for_worse helper_profits two_culprits one_of_two ],
    false_accusation: %w[ outsider_framed villain_protects both_hide_same friend_opposed two_culprits asker_is_cause ],
    rival_claim: %w[ old_wrong helper_profits abandon_place friend_opposed both_hide_same break_the_rule ],
    cut_off: %w[ abandon_place one_of_two asker_is_cause helper_profits trouble_shields cover_for_worse ]
  }.map { |key, twists| new(key: key.to_s, twists: twists) }.freeze
end
