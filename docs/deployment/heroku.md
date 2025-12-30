# Deploying Gumroad to Heroku

This guide provides comprehensive instructions for deploying Gumroad to Heroku, including all required add-ons, configuration, and production considerations.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
  - [1. Create Heroku Application](#1-create-heroku-application)
  - [2. Add Required Add-ons](#2-add-required-add-ons)
  - [3. Configure Environment Variables](#3-configure-environment-variables)
  - [4. Deploy the Application](#4-deploy-the-application)
  - [5. Database Setup](#5-database-setup)
  - [6. Configure Elasticsearch](#6-configure-elasticsearch)
  - [7. Set Up Sidekiq Workers](#7-set-up-sidekiq-workers)
- [Production Considerations](#production-considerations)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)

---

## Prerequisites

Before deploying to Heroku, ensure you have:

1. **Heroku CLI** installed: https://devcenter.heroku.com/articles/heroku-cli
2. **Git** installed and configured
3. **Heroku account** with billing enabled (required for add-ons)
4. **AWS account** for S3 storage and CloudFront CDN
5. **Stripe account** for payment processing
6. **Third-party service credentials** (see Environment Variables section)

## Quick Start

```bash
# Login to Heroku
heroku login

# Create the application
heroku create your-gumroad-app --stack heroku-22

# Add buildpacks (order matters - Node.js before Ruby)
heroku buildpacks:clear
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby

# Add essential add-ons (MySQL via JawsDB, not PostgreSQL)
heroku addons:create jawsdb:kitefin
heroku addons:create heroku-redis:premium-0
heroku addons:create bonsai:sandbox-6  # Elasticsearch
heroku addons:create memcachier:dev

# Configure environment variables (see detailed setup below)
# ...

# Deploy
git push heroku main

# Run database migrations
heroku run rails db:migrate
```

---

## Detailed Setup

### 1. Create Heroku Application

```bash
# Create app with specific stack
heroku create your-gumroad-app --stack heroku-22 --region us

# Or create in EU region for GDPR compliance
heroku create your-gumroad-app --stack heroku-22 --region eu
```

#### Add Required Buildpacks

Gumroad requires both Ruby and Node.js buildpacks:

```bash
heroku buildpacks:clear
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add heroku/ruby
```

**Note**: The order matters - Node.js must be added before Ruby so that npm dependencies are installed before asset compilation.

#### Create a `Procfile` for Heroku

Create a `Procfile` in your project root (if not already present):

```procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -q critical -q default -q low -q mongo
release: bundle exec rails db:migrate
```

### 2. Add Required Add-ons

#### Database: MySQL via ClearDB or JawsDB

Heroku's native PostgreSQL won't work since Gumroad uses MySQL. Use JawsDB or ClearDB:

```bash
# Option 1: JawsDB MySQL (Recommended)
heroku addons:create jawsdb:kitefin

# Option 2: ClearDB
heroku addons:create cleardb:ignite
```

After adding, get the connection URL:

```bash
heroku config:get JAWSDB_URL
# or
heroku config:get CLEARDB_DATABASE_URL
```

Parse this URL and set individual environment variables:

```bash
# Example: mysql://user:pass@host:3306/database
heroku config:set DATABASE_HOST=your-host.jawsdb.com
heroku config:set DATABASE_NAME=your-database-name
heroku config:set DATABASE_USERNAME=your-username
heroku config:set DATABASE_PASSWORD=your-password
heroku config:set DATABASE_PORT=3306
```

#### Redis

```bash
# For production
heroku addons:create heroku-redis:premium-0

# For staging/development
heroku addons:create heroku-redis:mini
```

Configure Redis hosts:

```bash
REDIS_URL=$(heroku config:get REDIS_URL)
heroku config:set REDIS_HOST=$REDIS_URL/0
heroku config:set SIDEKIQ_REDIS_HOST=$REDIS_URL/1
heroku config:set RPUSH_REDIS_HOST=$REDIS_URL/2
heroku config:set RACK_ATTACK_REDIS_HOST=$REDIS_URL/3
```

#### Elasticsearch

```bash
# Bonsai Elasticsearch (recommended)
heroku addons:create bonsai:sandbox-6

# Or SearchBox
heroku addons:create searchbox:starter
```

Configure after adding:

```bash
heroku config:set ELASTICSEARCH_HOST=$(heroku config:get BONSAI_URL)
```

#### Memcached

```bash
heroku addons:create memcachier:dev
```

Set the servers:

```bash
heroku config:set MEMCACHE_SERVERS=$(heroku config:get MEMCACHIER_SERVERS)
```

#### MongoDB (via MongoDB Atlas)

Gumroad uses MongoDB for logging. Set up MongoDB Atlas and configure:

```bash
heroku config:set MONGO_DATABASE_URL=your-mongodb-atlas-url
heroku config:set MONGO_DATABASE_NAME=gumroad_log_production
heroku config:set MONGO_DATABASE_USERNAME=your-username
heroku config:set MONGO_DATABASE_PASSWORD=your-password
```

### 3. Configure Environment Variables

Set all required environment variables from `.env.production.example`:

#### Core Rails Configuration

```bash
heroku config:set RAILS_ENV=production
heroku config:set RACK_ENV=production
heroku config:set RAILS_LOG_LEVEL=info
heroku config:set RAILS_MAX_THREADS=5
heroku config:set PUMA_WORKER_PROCESSES=2

# Generate a secure secret key
heroku config:set DEVISE_SECRET_KEY=$(openssl rand -hex 64)
heroku config:set SECRET_KEY_BASE=$(openssl rand -hex 64)
```

#### AWS/S3 Configuration

```bash
heroku config:set AWS_ACCESS_KEY_ID=your-access-key
heroku config:set AWS_SECRET_ACCESS_KEY=your-secret-key
heroku config:set AWS_DEFAULT_REGION=us-east-1
heroku config:set S3_BASE_URL_TEMPLATE=https://s3.amazonaws.com/{bucket}

# S3 Buckets
heroku config:set INVOICES_S3_BUCKET=your-invoices-bucket
heroku config:set REPORTING_S3_BUCKET_PROD=your-reporting-bucket
```

#### CloudFront Configuration

```bash
heroku config:set CLOUDFRONT_KEYPAIR_ID=your-keypair-id
heroku config:set CLOUDFRONT_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
heroku config:set CLOUDFRONT_DOWNLOAD_DISTRIBUTION_URL_PROD=https://your-distribution.cloudfront.net
heroku config:set FILE_DOWNLOAD_DISTRIBUTION_URL_PROD=https://your-file-distribution.cloudfront.net
```

#### Stripe Configuration

```bash
heroku config:set STRIPE_API_KEY=sk_live_your-key
heroku config:set STRIPE_CONNECT_CLIENT_ID=ca_your-client-id
heroku config:set STRIPE_PLATFORM_ACCOUNT_ID=acct_your-account
heroku config:set STRIPE_PUBLIC_KEY_PROD=pk_live_your-key
heroku config:set STRIPE__ENDPOINT_SECRET=whsec_your-webhook-secret
heroku config:set STRIPE_CONNECT__ENDPOINT_SECRET=whsec_your-connect-webhook-secret
```

#### PayPal Configuration (if using PayPal)

```bash
heroku config:set PAYPAL_CLIENT_ID=your-client-id
heroku config:set PAYPAL_CLIENT_SECRET=your-client-secret
heroku config:set PAYPAL_USERNAME=your-username
heroku config:set PAYPAL_PASSWORD=your-password
heroku config:set PAYPAL_SIGNATURE=your-signature
heroku config:set PAYPAL_MERCHANT_EMAIL=your@email.com
```

#### Email Configuration

```bash
# Resend (recommended)
heroku config:set RESEND_DEFAULT_API_KEY=re_your-key
heroku config:set RESEND_CREATORS_API_KEY=re_your-creators-key
heroku config:set RESEND_CUSTOMERS_API_KEY=re_your-customers-key

# Or SendGrid
heroku config:set SENDGRID_GUMROAD_TRANSACTIONS_API_KEY=SG.your-key
```

#### Other Required Variables

```bash
# Security
heroku config:set STRONGBOX_GENERAL="your-strongbox-key"
heroku config:set STRONGBOX_GENERAL_PASSWORD="your-password"
heroku config:set OBFUSCATE_IDS_CIPHER_KEY="your-cipher-key"
heroku config:set OBFUSCATE_IDS_NUMERIC_CIPHER_KEY="your-numeric-key"

# Google (for OAuth and reCAPTCHA)
heroku config:set GOOGLE_CLIENT_ID=your-client-id
heroku config:set GOOGLE_CLIENT_SECRET=your-secret
heroku config:set RECAPTCHA_LOGIN_SITE_KEY=your-site-key

# Bugsnag (error tracking)
heroku config:set BUGSNAG_API_KEY=your-bugsnag-key

# Tax Services
heroku config:set TAXJAR_API_KEY=your-taxjar-key
```

### 4. Deploy the Application

```bash
# Ensure you're on the correct branch
git checkout main

# Push to Heroku
git push heroku main

# Monitor the build
heroku logs --tail
```

### 5. Database Setup

After deployment, set up the database:

```bash
# Run migrations (automatically done via release phase if Procfile is configured)
heroku run rails db:migrate

# If fresh install, seed the database
heroku run rails db:seed
```

### 6. Configure Elasticsearch

After the application is deployed, reindex Elasticsearch:

```bash
heroku run rails console

# In the console:
DevTools.delete_all_indices_and_reindex_all
```

### 7. Set Up Sidekiq Workers

Scale up your worker dynos:

```bash
# Start with 1 worker
heroku ps:scale worker=1

# For production, consider 2-3 workers
heroku ps:scale worker=2
```

---

## Production Considerations

### Dyno Configuration

For production workloads, use performance dynos:

```bash
# Web dynos
heroku ps:type web=performance-m

# Worker dynos
heroku ps:type worker=performance-m

# Scale appropriately
heroku ps:scale web=2 worker=2
```

### SSL/TLS

Enable SSL for custom domains:

```bash
# Add custom domain
heroku domains:add www.yourdomain.com
heroku domains:add yourdomain.com

# Enable ACM for automatic SSL
heroku certs:auto:enable
```

### Database Configuration

For JawsDB, upgrade to a larger plan for production:

```bash
heroku addons:upgrade jawsdb:leopard
```

Configure read replicas if available:

```bash
heroku config:set USE_DB_WORKER_REPLICAS=false
```

### Asset Compilation

Ensure assets compile correctly during deploy:

```bash
# Check asset compilation in build logs
heroku builds:info
```

If assets fail, you may need to increase memory:

```bash
heroku config:set NODE_OPTIONS="--max_old_space_size=2048"
```

### AnyCable (WebSocket Support)

For real-time features, you'll need to set up AnyCable separately:

1. Deploy AnyCable-Go as a separate Heroku app or use a container service
2. Configure the WebSocket URL:

```bash
heroku config:set ANYCABLE_WEBSOCKET_URL=wss://cable.yourdomain.com/cable
heroku config:set ANYCABLE_SECRET=your-anycable-secret
```

---

## Monitoring and Maintenance

### Logging

```bash
# View logs
heroku logs --tail

# View only web logs
heroku logs --tail --ps web

# View worker logs
heroku logs --tail --ps worker
```

### Add Monitoring Add-ons

```bash
# New Relic APM
heroku addons:create newrelic:wayne

# Papertrail for log aggregation
heroku addons:create papertrail:choklad

# Librato for metrics
heroku addons:create librato:development
```

### Scheduled Tasks

Use Heroku Scheduler for cron-like tasks:

```bash
heroku addons:create scheduler:standard
heroku addons:open scheduler
```

Add scheduled jobs as needed (e.g., for cleanup tasks).

### Database Backups

```bash
# For JawsDB - use their dashboard or:
heroku addons:open jawsdb

# Schedule automatic backups via the add-on's dashboard
```

---

## Troubleshooting

### Build Failures

**Problem**: Asset compilation fails

```bash
# Increase Node.js memory limit
heroku config:set NODE_OPTIONS="--max_old_space_size=4096"

# Clear build cache
heroku builds:cache:purge
git commit --allow-empty -m "Purge build cache"
git push heroku main
```

**Problem**: Bundle install fails with sidekiq-pro

```bash
# Set the sidekiq-pro credentials
heroku config:set BUNDLE_GEMS__CONTRIBSYS__COM=your-key:x
```

### Runtime Errors

**Problem**: Database connection errors

```bash
# Check database configuration
heroku config | grep DATABASE

# Verify MySQL connection
heroku run rails console
# In console: ActiveRecord::Base.connection.execute("SELECT 1")
```

**Problem**: Redis connection errors

```bash
# Verify Redis URL
heroku config:get REDIS_URL

# Test connection
heroku run rails console
# In console: Redis.new(url: ENV['REDIS_URL']).ping
```

**Problem**: Elasticsearch not working

```bash
# Check Elasticsearch URL
heroku config:get ELASTICSEARCH_HOST

# Reindex
heroku run rails console
# In console: DevTools.delete_all_indices_and_reindex_all
```

### Memory Issues

**Problem**: R14 Memory quota exceeded

```bash
# Upgrade dyno size
heroku ps:type web=performance-m

# Or scale horizontally
heroku ps:scale web=3

# Consider reducing Puma workers/threads
heroku config:set PUMA_WORKER_PROCESSES=1
heroku config:set RAILS_MAX_THREADS=3
```

---

## Cost Estimation

Estimated monthly costs for a production Gumroad deployment on Heroku (2025 Pricing):

| Resource | Plan | Monthly Cost |
|----------|------|--------------|
| Web Dynos (2x Performance-M) | performance-m | $500 |
| Worker Dynos (2x Performance-M) | performance-m | $500 |
| JawsDB MySQL | Thresher (2GB RAM, 50GB storage) | $110 |
| Heroku Redis | Premium-0 | $15 |
| Bonsai Elasticsearch | Standard Fir | $30 |
| MemCachier | 100MB | $15 |
| MongoDB Atlas | M10 (Dedicated) | $57 |
| Papertrail | Choklad | $7 |
| **Total** | | **~$1,234/month** |

**Note**: Costs can vary significantly based on traffic and usage. Start small and scale as needed. Heroku bills by the second, so costs are prorated for dynos that don't run 24/7.

---

## Security Checklist

Before going to production, ensure:

- [ ] All API keys are properly set
- [ ] SSL is enabled for all custom domains
- [ ] Database connections use SSL
- [ ] Stripe webhooks are configured with correct endpoints
- [ ] Error monitoring (Bugsnag) is configured
- [ ] Rate limiting is enabled
- [ ] Strongbox encryption keys are set
- [ ] All OAuth secrets are properly configured

---

## Related Documentation

- [Production Environment](../production_environment.md) - Service configuration and requirements
- [Sidekiq](../sidekiq.md) - Background job guidelines and troubleshooting
- [Testing](../testing.md) - Testing purchases and payment flows
- [Deploying (Internal)](../deploying.md) - Internal Nomad/AWS deployment (for reference)

---

## Next Steps

1. Set up custom domains and SSL
2. Configure Stripe webhooks pointing to your Heroku app
3. Set up monitoring and alerting
4. Configure email delivery (verify sender domains)
5. Test the complete purchase flow
6. Set up automated backups
7. Document your deployment configuration
