import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

config :brain_cloud_web, BrainCloudWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))],
  server: System.get_env("PHX_SERVER") in ~w(true 1)

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :brain_cloud_web, BrainCloudWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/brain_cloud_web/router\.ex$"E,
        ~r"lib/brain_cloud_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :brain_cloud, BrainCloud.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  server? = System.get_env("PHX_SERVER") in ~w(true 1)

  public_uri =
    if server? do
      public_url =
        System.get_env("PUBLIC_APP_URL") ||
          raise "environment variable PUBLIC_APP_URL is missing; expected an https:// URL"

      case URI.parse(public_url) do
        %URI{scheme: "https", host: host, userinfo: nil, query: nil, fragment: nil, path: path} =
            uri
        when is_binary(host) and path in [nil, "", "/"] ->
          uri

        _invalid ->
          raise "environment variable PUBLIC_APP_URL must be an absolute https:// URL without credentials, path, query, or fragment"
      end
    else
      URI.parse("https://#{System.get_env("PHX_HOST", "localhost")}")
    end

  config :brain_cloud_web, BrainCloudWeb.Endpoint,
    url: [
      host: public_uri.host,
      port: public_uri.port || 443,
      scheme: public_uri.scheme
    ],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  config :brain_cloud_web,
         :public_app_url,
         "#{public_uri.scheme}://#{public_uri.host}" <>
           if(public_uri.port in [nil, 443], do: "", else: ":#{public_uri.port}")

  if server? do
    smtp_relay =
      case System.get_env("SMTP_RELAY") do
        value when is_binary(value) and value != "" -> value
        _missing -> raise "environment variable SMTP_RELAY is missing"
      end

    smtp_port =
      case Integer.parse(System.get_env("SMTP_PORT", "587")) do
        {port, ""} when port in 1..65_535 -> port
        _invalid -> raise "environment variable SMTP_PORT must be an integer from 1 through 65535"
      end

    smtp_tls =
      case System.get_env("SMTP_TLS", "always") do
        "always" -> :always
        "if_available" -> :if_available
        "never" -> :never
        _invalid -> raise "environment variable SMTP_TLS must be always, if_available, or never"
      end

    smtp_ssl =
      case System.get_env("SMTP_SSL", "false") do
        value when value in ["true", "1"] -> true
        value when value in ["false", "0"] -> false
        _invalid -> raise "environment variable SMTP_SSL must be true or false"
      end

    if smtp_ssl and smtp_tls != :never do
      raise "environment variable SMTP_TLS must be never when SMTP_SSL is true"
    end

    smtp_username = System.get_env("SMTP_USERNAME")
    smtp_password = System.get_env("SMTP_PASSWORD")

    smtp_auth =
      case {smtp_username, smtp_password} do
        {username, password} when username in [nil, ""] and password in [nil, ""] ->
          :never

        {username, password}
        when is_binary(username) and username != "" and is_binary(password) and password != "" ->
          :always

        _partial ->
          raise "SMTP_USERNAME and SMTP_PASSWORD must be configured together"
      end

    sender_address =
      case System.get_env("SMTP_FROM_ADDRESS") do
        value when is_binary(value) ->
          if Regex.match?(~r/^[^\s@]+@[^\s@]+$/, value),
            do: value,
            else: raise("environment variable SMTP_FROM_ADDRESS must be an email address")

        _missing ->
          raise "environment variable SMTP_FROM_ADDRESS is missing"
      end

    tls_verification = [
      versions: [:"tlsv1.2", :"tlsv1.3"],
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(smtp_relay),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

    mailer_config = [
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_relay,
      port: smtp_port,
      auth: smtp_auth,
      tls: smtp_tls,
      ssl: smtp_ssl,
      retries: 2
    ]

    mailer_config =
      if smtp_auth == :always,
        do: mailer_config ++ [username: smtp_username, password: smtp_password],
        else: mailer_config

    mailer_config =
      cond do
        smtp_ssl -> mailer_config ++ [sockopts: tls_verification]
        smtp_tls != :never -> mailer_config ++ [tls_options: tls_verification]
        true -> mailer_config
      end

    config :brain_cloud_web, BrainCloudWeb.Mailer, mailer_config

    config :brain_cloud_web,
           :mailer_from,
           {System.get_env("SMTP_FROM_NAME", "Brain Cloud"), sender_address}
  end

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :brain_cloud_web, BrainCloudWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :brain_cloud_web, BrainCloudWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  config :brain_cloud, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")
end
