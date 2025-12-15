# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-15

### Added

- Initial release of ms-graph-mailer gem
- ActionMailer delivery method for Microsoft Graph API
- OAuth 2.0 client credentials flow authentication
- Support for HTML and plain text emails
- Support for attachments (file attachments)
- Support for CC, BCC, and Reply-To recipients
- Comprehensive error handling with custom exception classes
- Configurable SSL verification
- Logging support
- Complete documentation and examples

### Features

- `MsGraphMailer::DeliveryMethod` - Main delivery method class
- `MsGraphMailer::TokenService` - OAuth token management
- Configuration system for tenant, client credentials
- Integration with Rails logger

[0.1.0]: https://github.com/zauberware/ms-graph-mailer/releases/tag/v0.1.0
