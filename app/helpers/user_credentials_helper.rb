module UserCredentialsHelper
  def masked_value(value)
    '*' * value.length
  end
end
