module ApplicationHelper
  def document_title
    title = content_for(:title)

    case
    when title.blank? then "Rokapi"
    when hotwire_native_app? then title
    else safe_join([ title, "Rokapi" ], " · ")
    end
  end

  def signed_number(number)
    format("%+d", number)
  end

  def lowercase(text)
    I18n.locale == :tr ? text.downcase(:turkic) : text.downcase
  end
end
