class ExampleComponentPreview < ViewComponent::Preview
  def default
    render(ExampleComponent.new(title: 'Hello World'))
  end

  def with_long_title
    render(ExampleComponent.new(title: 'This is a much longer title for the component'))
  end

  def icons
  end
end
