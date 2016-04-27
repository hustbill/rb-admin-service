class String
  def html_safe
    ActiveSupport::SafeBuffer.new(self)
  end
end
