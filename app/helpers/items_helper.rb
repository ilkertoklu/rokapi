module ItemsHelper
  def item_glyph(kind)
    case kind
    when "instant" then "flask"
    when "quest" then "book"
    else "pack"
    end
  end
end
