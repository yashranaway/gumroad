# Documentation overview

This directory contains comprehensive documentation for the Gumroad application.

## Getting started

- [Main README](../README.md) - Installation and local development setup
- [Windows development](development/windows.md) - Setting up on Windows with WSL
- [Mac setup without Docker](setup_without_docker/mac.md) - Native macOS development setup

## Deployment

### Internal deployment (AWS/Nomad)

- [Deploying](deploying.md) - Internal deployment to production/staging (Nomad/AWS)

### External platform deployment

- [Heroku deployment](deployment/heroku.md) - Complete guide to deploying on Heroku
- [Railway deployment](deployment/railway.md) - Complete guide to deploying on Railway

### Production setup

- [Production environment](production_environment.md) - Production service configuration

## Development guides

### Testing

- [Testing](testing.md) - Running tests, integration testing, and test payments
- [Users](users.md) - User authentication and test accounts

### Background jobs

- [Sidekiq](sidekiq.md) - Background job guidelines and management
- [Migrations](migrations.md) - Database migration best practices

### Debugging & monitoring

- [Debugging](debugging.md) - Debugging tips
- [Alerts](alerts.md) - Production alerts and troubleshooting
- [Logs](logs.md) - Logging information
- [Memory profiling](memory_profiling.md) - Memory debugging

## Features & integrations

### Payments

- [PayPal](paypal.md) - PayPal integration details
- [Apple pay](apple_pay.md) - Apple Pay setup

### Business logic

- [Taxes](taxes.md) - Tax handling documentation
- [Shipping](shipping.md) - Physical product shipping
- [Accounting](accounting.md) - Accounting and financial systems
- [Compliance](compliance.md) - Compliance and moderation

### Support

- [Support](support.md) - Customer support workflows
- [Helper widget](helper_widget.md) - Helper integration
