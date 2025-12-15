# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-15

### Added

- Automated CI/CD workflow with GitHub Actions
- Continuous Integration testing across Ruby 2.7, 3.0, 3.1, 3.2
- Automated releases using Trusted Publishing (no API keys needed)
- Version bump script (`scripts/bump_version.rb`)
- Comprehensive deployment documentation
- Rake tasks for version bumping (`rake version:major/minor/patch`)

### Changed

- **BREAKING**: Renamed gem from `microsoft-graph-mailer` to `ms-graph-mailer`
- **BREAKING**: Changed module namespace from `MicrosoftGraphMailer` to `MsGraphMailer`
- **BREAKING**: Changed require path from `microsoft/graph/mailer` to `ms/graph/mailer`
- Improved RuboCop configuration
- Enhanced CHANGELOG format with proper version links

## [0.1.0] - 2025-12-15

### Added

- Initial release of ms-graph-mailer gem
- ActionMailer delivery method for Microsoft Graph API
- OAuth 2.0 client credentials flow authentication with token caching
- Support for HTML and plain text emails
- Support for attachments (file attachments)
- Support for CC, BCC, and Reply-To recipients
- Comprehensive error handling with custom exception classes
- Configurable SSL verification
- Logging support
- Complete documentation and examples
- `MsGraphMailer::DeliveryMethod` - Main delivery method class
- `MsGraphMailer::TokenService` - OAuth token management with Rails.cache
- Configuration system for tenant, client credentials
- Integration with Rails logger

[1.0.0]: https://github.com/zauberware/ms-graph-mailer/releases/tag/v1.0.0
[0.1.0]: https://github.com/zauberware/ms-graph-mailer/releases/tag/v0.1.0
