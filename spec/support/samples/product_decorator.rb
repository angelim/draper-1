class ProductDecorator < Draper::Base
  decorates :product
  decorates_association :similar_products
  
  def awesome_title
    "Awesome Title"
  end
end
