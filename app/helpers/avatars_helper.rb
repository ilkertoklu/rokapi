module AvatarsHelper
  def avatar_tag(person, *modifiers, hidden: false)
    tag.span class: [ "avatar", *modifiers ], title: person.name, aria: { hidden: (true if hidden) } do
      if hidden
        person.initial
      else
        safe_join [ tag.span(person.initial, aria: { hidden: true }), tag.span(person.name, class: "visually-hidden") ]
      end
    end
  end
end
