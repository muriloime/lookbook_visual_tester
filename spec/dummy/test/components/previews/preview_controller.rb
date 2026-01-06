require 'lookbook/preview_controller_actions'

class PreviewController < ViewComponentsController
  include Lookbook::PreviewControllerActions

  helper Lookbook::PreviewHelper if defined?(Lookbook::PreviewHelper)
end
