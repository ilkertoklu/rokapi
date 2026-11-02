module ApplicationHelper
  def document_title
    title = content_for(:title) || "Rokapi"
    hotwire_native_app? ? title.delete_suffix(" · Rokapi") : title
  end
end
