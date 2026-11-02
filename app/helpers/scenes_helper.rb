module ScenesHelper
  def watch_status(scene)
    roll = scene.roll
    name = scene.active_player.name

    case
    when scene.choosing? then t("scenes.watch.deciding", name: name)
    when scene.rolling? then t("scenes.watch.rolling", name: name)
    when roll&.resolved? then t("scenes.watch.reading", name: name)
    else t("rolls.dice.resolving")
    end
  end
end
