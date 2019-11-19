# frozen_string_literal: true

module Spree
  class Promotion < Spree::Base
    module Rules
      # A rule to apply to an order greater than (or greater than or equal to)
      # a specific amount
      class ItemTotal < PromotionRule
        include ActiveSupport::Deprecation::DeprecatedConstantAccessor

        preference :amount, :decimal, default: 100.00
        preference :currency, :string, default: ->{ Spree::Config[:currency] }
        preference :operator, :string, default: 'gt'

        # The list of allowed operators names mapped to their symbols.
        def self.operators_map
          {
            gte: :>=,
            gt: :>,
          }
        end

        def self.operator_options
          operators_map.map do |name, _method|
            [I18n.t(name, scope: 'spree.item_total_rule.operators'), name]
          end
        end

        # @deprecated
        OPERATORS = operators_map.keys.map(&:to_s)
        deprecate_constant(
          :OPERATORS,
          :operators_map,
          message: "OPERATORS is deprecated! Use `operators_map.keys.map(&:to_s)` instead.",
          deprecator: Spree::Deprecation,
        )

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          return false unless order.currency == preferred_currency

          unless total_for_order(order).send(operator, threshold)
            eligibility_errors.add(:base, ineligible_message, error_code: ineligible_error_code)
          end

          eligibility_errors.empty?
        end

        private

        def operator
          self.class.operators_map.fetch(
            preferred_operator.to_sym,
            preferred_operator_default,
          )
        end

        def total_for_order(order)
          order.item_total
        end

        def threshold
          BigDecimal(preferred_amount.to_s)
        end

        def formatted_amount
          Spree::Money.new(preferred_amount, currency: preferred_currency).to_s
        end

        def ineligible_message
          if preferred_operator.to_s == 'gte'
            eligibility_error_message(:item_total_less_than, amount: formatted_amount)
          else
            eligibility_error_message(:item_total_less_than_or_equal, amount: formatted_amount)
          end
        end

        def ineligible_error_code
          if preferred_operator == 'gte'
            :item_total_less_than
          else
            :item_total_less_than_or_equal
          end
        end
      end
    end
  end
end
