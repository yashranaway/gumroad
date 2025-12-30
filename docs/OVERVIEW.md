# Documentation Overview

This directory contains comprehensive documentation for the Gumroad application.

## Getting Started

- [Main README](../README.md) - Installation and local development setup
- [Windows Development](development/windows.md) - Setting up on Windows with WSL
- [Mac Setup Without Docker](setup_without_docker/mac.md) - Native macOS development setup

## Deployment

### Internal Deployment (AWS/Nomad)

- [Deploying](deploying.md) - Internal deployment to production/staging (Nomad/AWS)

### External Platform Deployment

- [Heroku Deployment](deployment/heroku.md) - Complete guide to deploying on Heroku
- [Railway Deployment](deployment/railway.md) - Complete guide to deploying on Railway

### Production Setup

- [Production Environment](production_environment.md) - Production service configuration

## Development Guides

### Testing

- [Testing](testing.md) - Running tests, integration testing, and test payments
- [Users](users.md) - User authentication and test accounts

### Background Jobs

- [Sidekiq](sidekiq.md) - Background job guidelines and management
- [Migrations](migrations.md) - Database migration best practices

### Debugging & Monitoring

- [Debugging](debugging.md) - Debugging tips
- [Alerts](alerts.md) - Production alerts and troubleshooting
- [Logs](logs.md) - Logging information
- [Memory Profiling](memory_profiling.md) - Memory debugging

## Features & Integrations

### Payments

- [PayPal](paypal.md) - PayPal integration details
- [Apple Pay](apple_pay.md) - Apple Pay setup

### Business Logic

- [Taxes](taxes.md) - Tax handling documentation
- [Shipping](shipping.md) - Physical product shipping
- [Accounting](accounting.md) - Accounting and financial systems
- [Compliance](compliance.md) - Compliance and moderation

### Support

- [Support](support.md) - Customer support workflows
- [Helper Widget](helper_widget.md) - Helper integration
