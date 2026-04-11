# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Pulumi.jl, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please send an email to: **s.celles@gmail.com**

Include the following in your report:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You should receive a response within 48 hours. We will work with you to understand and address the issue before any public disclosure.

## Scope

This policy covers the Pulumi.jl Julia SDK, including:

- gRPC communication with the Pulumi engine
- Secret value handling and serialization
- Configuration value access
- Proto file generation and management

## Security Considerations

Pulumi.jl handles sensitive infrastructure data. Key areas of concern:

- **Secret values**: Output values marked as secret must remain encrypted in state
- **gRPC transport**: Communication with the Pulumi engine should use secure channels
- **Configuration secrets**: Secret configuration keys must not be logged or exposed
- **Serialization**: Protobuf serialization must not leak secret values
