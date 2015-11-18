module Stripe
  class ApplicationFee < APIResource
    extend Stripe::APIOperations::List

    def self.url
      '/v1/application_fees'
    end

    def refund(params={}, opts={})
      response, opts = request(:post, refund_url, params, opts)
      Util.convert_to_stripe_object(response, opts)
    end

    private

    def refund_url
      url + '/refunds'
    end
  end
end
