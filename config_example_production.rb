# frozen_string_literal: true

# Beispiel-Konfiguration für config/environments/production.rb
# Um Microsoft Graph Mailer in Production zu verwenden:

# 1. Füge diese Konfiguration zu config/environments/production.rb hinzu:

config.action_mailer.delivery_method = :microsoft_graph
config.action_mailer.microsoft_graph_settings = {
  ssl_verify: true # Auf false setzen, wenn SSL-Zertifikatsprobleme auftreten (nicht empfohlen)
}

# 2. Optional: SMTP als Fallback behalten (auskommentiert lassen)
# config.action_mailer.smtp_settings = {
#   address: ENV['DEFAULT_MAILER_SMTP_ADDRESS'],
#   port: ENV['DEFAULT_MAILER_SMTP_PORT'].to_i,
#   domain: ENV['DEFAULT_MAILER_SMTP_DOMAIN'],
#   user_name: ENV['DEFAULT_MAILER_SMTP_USERNAME'],
#   password: ENV['DEFAULT_MAILER_SMTP_PASSWORD'],
#   authentication: ENV['DEFAULT_MAILER_SMTP_AUTH'],
#   enable_starttls_auto: ENV['DEFAULT_MAILER_SMTP_ENABLE_STARTTLS_AUTO'] == 'true',
#   read_timeout: 60
# }

# 3. Stelle sicher, dass die Azure-Umgebungsvariablen gesetzt sind:
# AZURE_MAIL_APP_TENANT_ID
# AZURE_MAIL_APP_CLIENT_ID
# AZURE_MAIL_APP_CLIENT_SECRET
