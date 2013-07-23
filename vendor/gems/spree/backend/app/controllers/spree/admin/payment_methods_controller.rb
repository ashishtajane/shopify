module Spree
  module Admin
    class PaymentMethodsController < ResourceController
      skip_before_filter :load_resource, :only => [:create]
      before_filter :load_data
      before_filter :validate_payment_method_provider, :only => :create

      respond_to :html

      def create
        @payment_method = params[:payment_method].delete(:type).constantize.new(params[:payment_method])
        @object = @payment_method
        invoke_callbacks(:create, :before)
        if @payment_method.save
          invoke_callbacks(:create, :after)
          flash[:success] = Spree.t(:successfully_created, :resource => Spree.t(:payment_method))
          redirect_to edit_admin_payment_method_path(@payment_method)
        else
          invoke_callbacks(:create, :fails)
          respond_with(@payment_method)
        end
      end

      def update
        invoke_callbacks(:update, :before)
        payment_method_type = params[:payment_method].delete(:type)
        if @payment_method['type'].to_s != payment_method_type
          @payment_method.update_column(:type, payment_method_type)
          @payment_method = PaymentMethod.find(params[:id])
        end

        payment_method_params = params[ActiveModel::Naming.param_key(@payment_method)] || {}
        attributes = params[:payment_method].merge(payment_method_params)
        attributes.each do |k,v|
          if k.include?("password") && attributes[k].blank?
            attributes.delete(k)
          end
        end

        if @payment_method.update_attributes(attributes)
          invoke_callbacks(:update, :after)
          flash[:success] = Spree.t(:successfully_updated, :resource => Spree.t(:payment_method))
          redirect_to edit_admin_payment_method_path(@payment_method)
        else
          invoke_callbacks(:update, :fails)
          respond_with(@payment_method)
        end
      end

      private

      def load_data
        @providers = Gateway.providers.sort{|p1, p2| p1.name <=> p2.name }
      end

      def validate_payment_method_provider
        valid_payment_methods = Rails.application.config.spree.payment_methods.map(&:to_s)
        if !valid_payment_methods.include?(params[:payment_method][:type])
          flash[:error] = Spree.t(:invalid_payment_provider)
          redirect_to new_admin_payment_method_path
        end
      end
    end
  end
end
