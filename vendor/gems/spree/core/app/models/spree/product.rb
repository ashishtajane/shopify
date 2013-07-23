# PRODUCTS
# Products represent an entity for sale in a store.
# Products can have variations, called variants
# Products properties include description, permalink, availability,
#   shipping category, etc. that do not change by variant.
#
# MASTER VARIANT
# Every product has one master variant, which stores master price and sku, size and weight, etc.
# The master variant does not have option values associated with it.
# Price, SKU, size, weight, etc. are all delegated to the master variant.
# Contains on_hand inventory levels only when there are no variants for the product.
#
# VARIANTS
# All variants can access the product properties directly (via reverse delegation).
# Inventory units are tied to Variant.
# The master variant can have inventory units, but not option values.
# All other variants have option values and may have inventory units.
# Sum of on_hand each variant's inventory level determine "on_hand" level for the product.
#

module Spree
  class Product < ActiveRecord::Base
    acts_as_paranoid
    has_many :product_option_types, dependent: :destroy
    has_many :option_types, through: :product_option_types
    has_many :product_properties, dependent: :destroy
    has_many :properties, through: :product_properties

    has_many :classifications, dependent: :delete_all
    has_many :taxons, through: :classifications
    has_and_belongs_to_many :promotion_rules, join_table: :spree_products_promotion_rules

    belongs_to :tax_category, class_name: 'Spree::TaxCategory'
    belongs_to :shipping_category, class_name: 'Spree::ShippingCategory'

    has_one :master,
      class_name: 'Spree::Variant',
      conditions: { is_master: true },
      dependent: :destroy

    has_many :variants,
      class_name: 'Spree::Variant',
      conditions: { is_master: false, deleted_at: nil },
      order: "#{::Spree::Variant.quoted_table_name}.position ASC"

    has_many :variants_including_master,
      class_name: 'Spree::Variant',
      dependent: :destroy,
      order: "#{::Spree::Variant.quoted_table_name}.position ASC"

    has_many :prices, through: :variants, order: 'spree_variants.position, spree_variants.id, currency'
    has_many :stock_items, through: :variants

    delegate_belongs_to :master, :sku, :price, :currency, :display_amount, :display_price, :weight, :height, :width, :depth, :is_master, :has_default_price?, :cost_currency, :price_in, :amount_in
    delegate_belongs_to :master, :cost_price if Variant.table_exists? && Variant.column_names.include?('cost_price')

    after_create :set_master_variant_defaults
    after_create :add_properties_and_option_types_from_prototype
    after_create :build_variants_from_option_values_hash, if: :option_values_hash
    after_save :save_master

    delegate :images, to: :master, prefix: true
    alias_method :images, :master_images

    has_many :variant_images, source: :images, through: :variants_including_master, order: :position

    accepts_nested_attributes_for :variants, allow_destroy: true

    validates :name, :permalink, presence: true
    validates :price, presence: true, if: proc { Spree::Config[:require_master_price] }

    attr_accessor :option_values_hash

    attr_accessible :name, :description, :available_on, :permalink, :meta_description,
                    :meta_keywords, :price, :sku, :deleted_at, :prototype_id,
                    :option_values_hash, :weight, :height, :width, :depth,
                    :shipping_category_id, :tax_category_id, :product_properties_attributes,
                    :variants_attributes, :taxon_ids, :option_type_ids, :cost_currency

    attr_accessible :cost_price if Variant.table_exists? && Variant.column_names.include?('cost_price')

    accepts_nested_attributes_for :product_properties, allow_destroy: true, reject_if: lambda { |pp| pp[:property_name].blank? }

    make_permalink order: :name

    alias :options :product_option_types

    after_initialize :ensure_master

    def variants_with_only_master
      ActiveSupport::Deprecation.warn("[SPREE] Spree::Product#variants_with_only_master will be deprecated in Spree 1.3. Please use Spree::Product#master instead.")
      master
    end

    def to_param
      permalink.present? ? permalink : (permalink_was || name.to_s.to_url)
    end

    # the master variant is not a member of the variants array
    def has_variants?
      variants.any?
    end

    def tax_category
      if self[:tax_category_id].nil?
        TaxCategory.where(is_default: true).first
      else
        TaxCategory.find(self[:tax_category_id])
      end
    end

    # Adding properties and option types on creation based on a chosen prototype
    attr_reader :prototype_id
    def prototype_id=(value)
      @prototype_id = value.to_i
    end

    # Ensures option_types and product_option_types exist for keys in option_values_hash
    def ensure_option_types_exist_for_values_hash
      return if option_values_hash.nil?
      option_values_hash.keys.map(&:to_i).each do |id|
        self.option_type_ids << id unless option_type_ids.include?(id)
        product_option_types.create({option_type_id: id}, without_protection: true) unless product_option_types.pluck(:option_type_id).include?(id)
      end
    end

    # for adding products which are closely related to existing ones
    # define "duplicate_extra" for site-specific actions, eg for additional fields
    def duplicate
      duplicator = ProductDuplicator.new(self)
      duplicator.duplicate
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      !!deleted_at
    end

    def available?
      !(available_on.nil? || available_on.future?)
    end

    # split variants list into hash which shows mapping of opt value onto matching variants
    # eg categorise_variants_from_option(color) => {"red" -> [...], "blue" -> [...]}
    def categorise_variants_from_option(opt_type)
      return {} unless option_types.include?(opt_type)
      variants.active.group_by { |v| v.option_values.detect { |o| o.option_type == opt_type} }
    end

    def self.like_any(fields, values)
      where_str = fields.map { |field| Array.new(values.size, "#{self.quoted_table_name}.#{field} #{LIKE} ?").join(' OR ') }.join(' OR ')
      self.where([where_str, values.map { |value| "%#{value}%" } * fields.size].flatten)
    end

    # Suitable for displaying only variants that has at least one option value.
    # There may be scenarios where an option type is removed and along with it
    # all option values. At that point all variants associated with only those
    # values should not be displayed to frontend users. Otherwise it breaks the
    # idea of having variants
    def variants_and_option_values(current_currency = nil)
      variants.includes(:option_values).active(current_currency).select do |variant|
        variant.option_values.any?
      end
    end

    def empty_option_values?
      options.empty? || options.any? do |opt|
        opt.option_type.option_values.empty?
      end
    end

    def property(property_name)
      return nil unless prop = properties.find_by_name(property_name)
      product_properties.find_by_property_id(prop.id).try(:value)
    end

    def set_property(property_name, property_value)
      ActiveRecord::Base.transaction do
        property = Property.where(name: property_name).first_or_create!(presentation: property_name)
        product_property = ProductProperty.where(product_id: id, property_id: property.id).first_or_initialize
        product_property.value = property_value
        product_property.save!
      end
    end

    def possible_promotions
      promotion_ids = promotion_rules.map(&:activator_id).uniq
      Spree::Promotion.advertised.where(id: promotion_ids).reject(&:expired?)
    end

    def total_on_hand
      if Spree::Config.track_inventory_levels
        self.stock_items.sum(&:count_on_hand)
      else
        Float::INFINITY
      end
    end

    # Master variant may be deleted (i.e. when the product is deleted)
    # which would make AR's default finder return nil.
    # This is a stopgap for that little problem.
    def master
      super || variants_including_master.with_deleted.where(:is_master => true).first
    end

    private

      # Builds variants from a hash of option types & values
      def build_variants_from_option_values_hash
        ensure_option_types_exist_for_values_hash
        values = option_values_hash.values
        values = values.inject(values.shift) { |memo, value| memo.product(value).map(&:flatten) }

        values.each do |ids|
          variant = variants.create({ option_value_ids: ids, price: master.price }, without_protection: true)
        end
        save
      end

      def add_properties_and_option_types_from_prototype
        if prototype_id && prototype = Spree::Prototype.find_by_id(prototype_id)
          prototype.properties.each do |property|
            product_properties.create({property: property}, without_protection: true)
          end
          self.option_types = prototype.option_types
        end
      end

      # ensures the master variant is flagged as such
      def set_master_variant_defaults
        master.is_master = true
      end

      # there's a weird quirk with the delegate stuff that does not automatically save the delegate object
      # when saving so we force a save using a hook.
      def save_master
        master.save if master && (master.changed? || master.new_record? || (master.default_price && (master.default_price.changed || master.default_price.new_record)))
      end

      def ensure_master
        return unless new_record?
        self.master ||= Variant.new
      end
  end
end

require_dependency 'spree/product/scopes'
