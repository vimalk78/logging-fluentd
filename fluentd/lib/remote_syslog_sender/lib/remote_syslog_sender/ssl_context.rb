# frozen_string_literal: true

require "openssl"

module RemoteSyslogSender
  module SslContext
    CLIENT_CERT_DELIMITER = "\n-----END CERTIFICATE-----\n"

    def self.read_ssl_file(path)
      return nil if path.nil? || path.respond_to?(:strip) && path.strip.empty?
      File.read(path)
    end

    def self.build(ssl_method: 'TLSv1_2', ca_cert_file_path: nil, ca_cert: nil, client_cert: nil, client_cert_key: nil, client_cert_key_password: nil, client_cert_chain: nil, ca_certs_from_system: nil, verify_hostname: true, verify_mode: nil)
      return nil unless ca_cert_file_path || ca_cert || client_cert || client_cert_key || client_cert_key_password || client_cert_chain || ca_certs_from_system

      ssl_context = OpenSSL::SSL::SSLContext.new(ssl_method)

      if client_cert && client_cert_key
        if client_cert_key_password
          cert_key = OpenSSL::PKey.read(read_ssl_file(client_cert_key), client_cert_key_password)
        else
          cert_key = OpenSSL::PKey.read(read_ssl_file(client_cert_key))
        end
        context_params = {
          cert: OpenSSL::X509::Certificate.new(read_ssl_file(client_cert)),
          key: cert_key
        }
        if client_cert_chain
          certs = []
          client_cert_chain.split(CLIENT_CERT_DELIMITER).each do |cert|
            cert += CLIENT_CERT_DELIMITER
            certs << OpenSSL::X509::Certificate.new(cert)
          end
          context_params[:extra_chain_cert] = certs
        end
        ssl_context.set_params(context_params)
      elsif client_cert && !client_cert_key
        raise ArgumentError, "Remote syslog sender initialized with `ssl_client_cert` but no `ssl_client_cert_key`. Please provide both."
      elsif !client_cert && client_cert_key
        raise ArgumentError, "Remote syslog sender initialized with `ssl_client_cert_key`, but no `ssl_client_cert`. Please provide both."
      elsif client_cert_chain && !client_cert
        raise ArgumentError, "Remote syslog sender initialized with `ssl_client_cert_chain`, but no `ssl_client_cert`. Please provide cert, key and chain."
      elsif client_cert_chain && !client_cert_key
        raise ArgumentError, "Remote syslog sender initialized with `ssl_client_cert_chain`, but no `ssl_client_cert_key`. Please provide cert, key and chain."
      elsif client_cert_key_password && !client_cert_key
        raise ArgumentError, "Remote syslog sender initialized with `ssl_client_cert_key_password`, but no `ssl_client_cert_key`. Please provide both."
      end

      if ca_cert || ca_cert_file_path || ca_certs_from_system
        store = OpenSSL::X509::Store.new
        Array(ca_cert).each do |cert|
          store.add_cert(OpenSSL::X509::Certificate.new(cert))
        end
        Array(ca_cert_file_path).each do |cert_file_path|
          store.add_file(cert_file_path)
        end
        if ca_certs_from_system
          store.set_default_paths
        end
        ssl_context.cert_store = store
      end

      context.verify_mode = verify_mode if verify_mode
      # Verify certificate hostname if supported (ruby >= 2.4.0)
      ssl_context.verify_hostname = verify_hostname if ssl_context.respond_to?(:verify_hostname=)

      ssl_context
    end
  end
end
