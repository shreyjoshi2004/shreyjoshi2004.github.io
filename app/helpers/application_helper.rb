module ApplicationHelper
  ICON_DIR = Rails.root.join("app/assets/images/icons")

  # Inline an SVG from app/assets/images/icons so it inherits currentColor.
  def icon(name)
    svg = File.read(ICON_DIR.join("#{name}.svg"))
    svg.sub("<svg ", '<svg aria-hidden="true" focusable="false" ').html_safe
  end
end
