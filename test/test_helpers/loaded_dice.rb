module LoadedDice
  def with_die(value)
    Choice.define_method(:rand) { |*| value }
    yield
  ensure
    Choice.remove_method(:rand)
  end
end
