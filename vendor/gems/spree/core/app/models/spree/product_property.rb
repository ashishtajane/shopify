module Spree
  class ProductProperty < ActiveRecord::Base
    belongs_to :product, class_name: 'Spree::Product'
    belongs_to :property, class_name: 'Spree::Property'

    validates :property, presence: true
    validates :value, length: { maximum: 255 }

    attr_accessible :property_name, :value, :position

    default_scope order: "#{self.table_name}.position"

    # virtual attributes for use with AJAX completion stuff
    def property_name
      property.name if property
    end

    def property_name=(name)
      unless name.blank?
        unless property = Property.find_by_name(name)
          property = Property.create(name: name, presentation: name)
        end
        self.property = property
      end
    end
  end
end
