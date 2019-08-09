# frozen_string_literal: true

module Stripe
  class SubscriptionSchedule < APIResource
    extend Stripe::APIOperations::Create
    extend Stripe::APIOperations::List
    include Stripe::APIOperations::Save

    OBJECT_NAME = "subscription_schedule".freeze

    custom_method :cancel, http_verb: :post
    custom_method :release, http_verb: :post

    def cancel(params = {}, opts = {})
      request_stripe_object(
        method: :post,
        path: resource_url + "/cancel",
        params: params,
        opts: opts
      )
    end

    def release(params = {}, opts = {})
      request_stripe_object(
        method: :post,
        path: resource_url + "/release",
        params: params,
        opts: opts
      )
    end

    def revisions(params = {}, opts = {})
      resp, opts = request(:get, resource_url + "/revisions", params, opts)
      Util.convert_to_stripe_object(resp.data, opts)
    end
  end
end
