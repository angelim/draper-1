class WidgetDecorator < ProductDecorator
  decorates :widget
  def awesome_title
    "Widget Title"
  end
end
