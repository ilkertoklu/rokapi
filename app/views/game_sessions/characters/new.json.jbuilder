json.free_points Character::FREE_POINTS
json.stat_cap Character::STAT_CAP

json.stats Character::Stat.all do |stat|
  json.(stat, :key, :label)
end

json.races Character::Race.all do |race|
  json.(race, :key, :label, :description)
end

json.klasses Character::Klass.all do |klass|
  json.(klass, :key, :label, :description, :base_hp, :base_stats)
end

json.backgrounds Character::Background.all do |background|
  json.(background, :key, :label, :description)
end
