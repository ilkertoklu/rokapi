class RenameTroublesThatNeededMadeUpMagic < ActiveRecord::Migration[8.1]
  RENAMES = { "dark_wards" => "set_fire", "dead_fire" => "unlit_beacon", "sleeping_sickness" => "fever", "broken_oath" => "broken_truce" }

  def up
    RENAMES.each { |from, to| rename_trouble from, to }
  end

  def down
    RENAMES.each { |from, to| rename_trouble to, from }
  end

  private
    def rename_trouble(from, to)
      execute "UPDATE game_sessions SET trouble = #{quote(to)} WHERE trouble = #{quote(from)}"
    end

    def quote(value) = connection.quote(value)
end
