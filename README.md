# Ms Graph Mailer

A custom ActionMailer delivery method that sends emails via Microsoft Graph API using OAuth 2.0 client credentials flow.

## Features

- 🚀 Send emails through Microsoft Graph API (v1.0)
- 🔐 OAuth 2.0 authentication with client credentials flow
- 📎 Support for attachments
- 📧 Support for HTML and plain text emails
- 📬 Support for CC, BCC, and Reply-To recipients
- 🔍 Comprehensive error handling and logging
- ⚙️ Configurable SSL verification

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ms-graph-mailer', git: 'https://github.com/zauberware/ms-graph-mailer'
```

Then execute:

```bash
bundle install
```

## Configuration

### Azure AD App Setup

1. Register an application in Azure Active Directory
2. Grant the application `Mail.Send` API permission (Application permission, not delegated)
3. Generate a client secret
4. Note down:
   - Tenant ID
   - Client ID (Application ID)
   - Client Secret

### Rails Configuration

Create an initializer file `config/initializers/ms_graph_mailer.rb`:

```ruby
MsGraphMailer.configure do |config|
  config.tenant_id = ENV['AZURE_MAIL_APP_TENANT_ID']
  config.client_id = ENV['AZURE_MAIL_APP_CLIENT_ID']
  config.client_secret = ENV['AZURE_MAIL_APP_CLIENT_SECRET']
  config.logger = Rails.logger
end
```

Configure ActionMailer to use the Microsoft Graph delivery method:

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :microsoft_graph
config.action_mailer.microsoft_graph_settings = {
  ssl_verify: true # Set to false to disable SSL verification (not recommended for production)
}
```

### Environment Variables

Set the following environment variables:

```bash
AZURE_MAIL_APP_TENANT_ID=your-tenant-id
AZURE_MAIL_APP_CLIENT_ID=your-client-id
AZURE_MAIL_APP_CLIENT_SECRET=your-client-secret
```

## Usage

Once configured, the gem works automatically with ActionMailer. Just send emails as you normally would:

```ruby
require 'ms/graph/mailer'

class UserMailer < ApplicationMailer
  def welcome_email(user)
    mail(
      to: user.email,
      subject: 'Welcome to Our App',
      from: 'noreply@example.com'
    )
  end
end

# Send the email
UserMailer.welcome_email(user).deliver_now
```

### Important Notes

- The `from` email address must be a valid mailbox in your Microsoft 365 tenant
- The Azure AD application must have the necessary permissions to send emails on behalf of the sender
- Emails are sent using the `/users/{sender}/sendMail` endpoint

## Error Handling

The gem raises specific exceptions for different error scenarios:

- `MsGraphMailer::ConfigurationError` - Invalid or missing configuration
- `MsGraphMailer::AuthenticationError` - OAuth authentication failures
- `MsGraphMailer::DeliveryError` - Email delivery failures

## Development

After checking out the repo, run:

```bash
bundle install
```

Run tests:

```bash
bundle exec rspec
```

Run RuboCop:

```bash
bundle exec rubocop
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zauberware/ms-graph-mailer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

Developed by [Zauberware Technologies GmbH](https://zauberware.com)
