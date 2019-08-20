# frozen_string_literal: true

module Stripe
  # Manages connections across multiple hosts which is useful because the
  # library may connect to multiple hosts during a typical session (main API,
  # Connect, Uploads). Ruby doesn't provide an easy way to make this happen
  # easily, so this class is designed to track what we're connected to and
  # manage the lifecycle of those connections.
  #
  # Note that this class in itself is *not* thread safe. We expect it to be
  # instantiated once per thread.
  #
  # Note also that this class doesn't currently clean up after itself because
  # it expects to only ever have a few connections (unless `.clear` is called
  # manually). It'd be possible to tank memory by constantly changing the value
  # of `Stripe.api_base` or the like. A possible improvement might be to detect
  # and prune old connections whenever a request is executed.
  class ConnectionManager
    def initialize
      @active_connections = {}
    end

    # Finishes any active connections by closing their TCP connection and
    # clears them from internal tracking.
    def clear
      @active_connections.each do |_, connection|
        connection.finish
      end
      @active_connections = {}
    end

    # Gets a connection for a given URI. This is for internal use only as it's
    # subject to change (we've moved between HTTP client schemes in the past
    # and may do it again).
    #
    # `uri` is expected to be a string.
    def connection_for(uri)
      u = URI.parse(uri)
      connection = @active_connections[[u.host, u.port]]

      if connection.nil?
        connection = create_connection(u)

        # TODO: what happens after TTL?
        connection.start

        @active_connections[[u.host, u.port]] = connection
      end

      connection
    end

    # Executes an HTTP request to the given URI with the given method. Also
    # allows a request body, headers, and query string to be specified.
    def execute_request(method, uri, body: nil, headers: nil, query: nil)
      # Perform some basic argument validation because it's easy to get
      # confused between strings and hashes for things like body and query
      # parameters.
      raise ArgumentError, "method should be a symbol" \
        unless method.is_a?(Symbol)
      raise ArgumentError, "uri should be a string" \
        unless uri.is_a?(String)
      raise ArgumentError, "body should be a string" \
        if body && !body.is_a?(String)
      raise ArgumentError, "headers should be a hash" \
        if headers && !headers.is_a?(Hash)
      raise ArgumentError, "query should be a string" \
        if query && !query.is_a?(String)

      connection = connection_for(uri)

      u = URI.parse(uri)
      path = if query
               u.path + "?" + query
             else
               u.path
             end

      connection.send_request(method.to_s.upcase, path, body, headers)
    end

    #
    # private
    #

    # `uri` should be a parsed `URI` object.
    private def create_connection(uri)
      # These all come back as `nil` if no proxy is configured.
      proxy_host, proxy_port, proxy_user, proxy_pass = proxy_parts

      connection = Net::HTTP.new(uri.host, uri.port,
                                 proxy_host, proxy_port,
                                 proxy_user, proxy_pass)

      connection.open_timeout = Stripe.open_timeout
      connection.read_timeout = Stripe.read_timeout

      connection.use_ssl = uri.scheme == "https"

      if Stripe.verify_ssl_certs
        connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
        connection.cert_store = Stripe.ca_store
      else
        connection.verify_mode = OpenSSL::SSL::VERIFY_NONE

        unless @verify_ssl_warned
          @verify_ssl_warned = true
          warn("WARNING: Running without SSL cert verification. " \
            "You should never do this in production. " \
            "Execute `Stripe.verify_ssl_certs = true` to enable " \
            "verification.")
        end
      end

      connection
    end

    # `Net::HTTP` somewhat awkwardly requires each component of a proxy URI
    # (host, port, etc.) rather than the URI itself. This method simply parses
    # out those pieces to make passing them into a new connection a little less
    # ugly.
    private def proxy_parts
      if Stripe.proxy.nil?
        [nil, nil, nil, nil]
      else
        u = URI.parse(Stripe.proxy)
        [u.host, u.port, u.user, u.password]
      end
    end
  end
end
