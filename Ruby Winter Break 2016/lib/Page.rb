class Page

  attr_accessor :widgets

  def initialize
    @widgets = []
  end

  def add_widget(widget)
    @widgets.each do |widget2|
      if widget.id == widget2.id
        widget.duplicate = true
        widget2.duplicate = true
      end
    end
    @widgets << widget
  end

end
