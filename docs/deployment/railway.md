# Deploying Gumroad to Railway

This guide provides comprehensive instructions for deploying Gumroad to Railway, a modern cloud platform that offers an excellent developer experience with built-in databases and seamless GitHub integration.

## Table of Contents

- [Why Railway?](#why-railway)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
  - [1. Create Railway Project](#1-create-railway-project)
  - [2. Deploy Services](#2-deploy-services)
  - [3. Configure Environment Variables](#3-configure-environment-variables)
  - [4. Database Setup](#4-database-setup)
  - [5. Configure Additional Services](#5-configure-additional-services)
  - [6. Deploy the Application](#6-deploy-the-application)
- [Multi-Service Architecture](#multi-service-architecture)
- [Production Considerations](#production-considerations)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Cost Estimation](#cost-estimation)

---

## Why Railway?

Railway offers several advantages for deploying Gumroad:

- **Native MySQL support** (unlike Heroku which requires add-ons)
- **Built-in Redis, MongoDB, and other databases**
- **Private networking** between services
- **Simple environment variable management**
- **GitHub integration** with automatic deployments
- **Usage-based pricing** - pay for what you use
- **No dyno sleeping** on all plans

---

## Prerequisites

Before deploying to Railway, ensure you have:

1. **Railway account**: https://railway.app
2. **GitHub account** (recommended for automatic deployments)
3. **Railway CLI** (optional but recommended):
   ```bash
   npm install -g @railway/cli
   railway login
   ```
4. **AWS account** for S3 storage and CloudFront CDN
5. **Stripe account** for payment processing
6. **Third-party service credentials** (see Environment Variables section)

---

## Quick Start

### Via Railway Dashboard

1. Go to [railway.app/new](https://railway.app/new)
2. Select "Deploy from GitHub repo"
3. Connect your Gumroad repository
4. Railway will auto-detect the Rails application
5. Add required services (MySQL, Redis, etc.)
6. Configure environment variables
7. Deploy!

### Via Railway CLI

```bash
# Login to Railway
railway login

# Create new project
railway init

# Link to GitHub repo
railway link

# Add services
railway add --database mysql
railway add --database redis
railway add --database mongo

# Deploy
railway up
```

---

## Detailed Setup

### 1. Create Railway Project

#### Option A: Dashboard (Recommended for First Time)

1. Visit [railway.app/new](https://railway.app/new)
2. Click "Deploy from GitHub repo"
3. Authorize Railway to access your repository
4. Select your Gumroad repository
5. Railway will create a new project

#### Option B: CLI

```bash
# Initialize new project
railway init

# Or link existing project
railway link
```

### 2. Deploy Services

Railway makes it easy to add required services. From your project dashboard, click "+ New" and add:

#### MySQL Database

```bash
# Via CLI
railway add --database mysql
```

Or in Dashboard: New → Database → MySQL

Railway will automatically provision MySQL 8.0 and set the `MYSQL_URL` variable.

#### Redis

```bash
# Via CLI
railway add --database redis
```

Or in Dashboard: New → Database → Redis

This sets `REDIS_URL` automatically.

#### MongoDB

```bash
# Via CLI
railway add --database mongo
```

Or in Dashboard: New → Database → MongoDB

This sets `MONGO_URL` automatically.

#### Elasticsearch (via Docker Template)

Railway doesn't have built-in Elasticsearch, but you can deploy it:

1. New → Empty Service
2. Settings → Deploy → Docker Image
3. Enter: `elasticsearch:7.9.3`
4. Add environment variables:
   ```
   discovery.type=single-node
   ES_JAVA_OPTS=-Xms512m -Xmx512m
   ```

### 3. Configure Environment Variables

Click on your main application service, go to "Variables" tab, and add the following:

#### Railway-Specific Configuration

Railway provides internal URLs for services. Reference them using Railway's variable syntax:

```bash
# Database configuration
DATABASE_HOST=${{MySQL.MYSQLHOST}}
DATABASE_PORT=${{MySQL.MYSQLPORT}}
DATABASE_NAME=${{MySQL.MYSQLDATABASE}}
DATABASE_USERNAME=${{MySQL.MYSQLUSER}}
DATABASE_PASSWORD=${{MySQL.MYSQLPASSWORD}}

# Redis configuration
REDIS_HOST=${{Redis.REDIS_URL}}/0
SIDEKIQ_REDIS_HOST=${{Redis.REDIS_URL}}/1
RPUSH_REDIS_HOST=${{Redis.REDIS_URL}}/2
RACK_ATTACK_REDIS_HOST=${{Redis.REDIS_URL}}/3

# MongoDB configuration
MONGO_DATABASE_URL=${{MongoDB.MONGOHOST}}:${{MongoDB.MONGOPORT}}
MONGO_DATABASE_NAME=${{MongoDB.MONGO_INITDB_DATABASE}}
MONGO_DATABASE_USERNAME=${{MongoDB.MONGO_INITDB_ROOT_USERNAME}}
MONGO_DATABASE_PASSWORD=${{MongoDB.MONGO_INITDB_ROOT_PASSWORD}}

# Elasticsearch
ELASTICSEARCH_HOST=http://${{Elasticsearch.RAILWAY_PRIVATE_DOMAIN}}:9200
```

#### Core Rails Configuration

```bash
# Rails environment
RAILS_ENV=production
RACK_ENV=production
RAILS_LOG_LEVEL=info
RAILS_MAX_THREADS=5
PUMA_WORKER_PROCESSES=2

# Generate secure keys (run locally and paste values)
# openssl rand -hex 64
DEVISE_SECRET_KEY=your-generated-key
SECRET_KEY_BASE=your-generated-key
```

#### AWS/S3 Configuration

```bash
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_DEFAULT_REGION=us-east-1
S3_BASE_URL_TEMPLATE=https://s3.amazonaws.com/{bucket}

# S3 Buckets
INVOICES_S3_BUCKET=your-invoices-bucket
REPORTING_S3_BUCKET_PROD=your-reporting-bucket
```

#### CloudFront Configuration

```bash
CLOUDFRONT_KEYPAIR_ID=your-keypair-id
CLOUDFRONT_PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----
CLOUDFRONT_DOWNLOAD_DISTRIBUTION_URL_PROD=https://your-distribution.cloudfront.net
FILE_DOWNLOAD_DISTRIBUTION_URL_PROD=https://your-file-distribution.cloudfront.net
```

#### Stripe Configuration

```bash
STRIPE_API_KEY=sk_live_your-key
STRIPE_CONNECT_CLIENT_ID=ca_your-client-id
STRIPE_PLATFORM_ACCOUNT_ID=acct_your-account
STRIPE_PUBLIC_KEY_PROD=pk_live_your-key
STRIPE__ENDPOINT_SECRET=whsec_your-webhook-secret
STRIPE_CONNECT__ENDPOINT_SECRET=whsec_your-connect-webhook-secret
```

#### PayPal Configuration

```bash
PAYPAL_CLIENT_ID=your-client-id
PAYPAL_CLIENT_SECRET=your-client-secret
PAYPAL_USERNAME=your-username
PAYPAL_PASSWORD=your-password
PAYPAL_SIGNATURE=your-signature
PAYPAL_MERCHANT_EMAIL=your@email.com
```

#### Email Configuration

```bash
# Resend (recommended)
RESEND_DEFAULT_API_KEY=re_your-key
RESEND_CREATORS_API_KEY=re_your-creators-key
RESEND_CUSTOMERS_API_KEY=re_your-customers-key
RESEND_CUSTOMERS_LEVEL_2_API_KEY=re_your-level2-key
RESEND_FOLLOWERS_API_KEY=re_your-followers-key
```

#### Security & Encryption

```bash
STRONGBOX_GENERAL=your-strongbox-public-and-private-key
STRONGBOX_GENERAL_PASSWORD=your-password
OBFUSCATE_IDS_CIPHER_KEY=your-cipher-key
OBFUSCATE_IDS_NUMERIC_CIPHER_KEY=your-numeric-key
```

#### Other Required Variables

```bash
# Google OAuth & reCAPTCHA
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-secret
RECAPTCHA_LOGIN_SITE_KEY=your-site-key
RECAPTCHA_SIGNUP_SITE_KEY=your-site-key
ENTERPRISE_RECAPTCHA_API_KEY=your-api-key

# Error tracking
BUGSNAG_API_KEY=your-bugsnag-key

# Tax services
TAXJAR_API_KEY=your-taxjar-key
VATSTACK_API_KEY=your-vatstack-key
```

### 4. Database Setup

#### Configure `railway.toml`

Create a `railway.toml` file in your project root:

```toml
[build]
builder = "nixpacks"
buildCommand = "npm install && bundle install"

[deploy]
startCommand = "bundle exec rails db:migrate && bundle exec puma -C config/puma.rb"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "on_failure"
restartPolicyMaxRetries = 5
```

#### Database Initialization

After first deployment, run migrations:

```bash
# Via CLI
railway run rails db:migrate

# Or in Railway shell (from dashboard)
bundle exec rails db:migrate
```

For a fresh install, seed the database:

```bash
railway run rails db:seed
```

### 5. Configure Additional Services

#### Sidekiq Worker Service

Create a separate service for Sidekiq workers:

1. New → Empty Service
2. Settings → Source → Connect to same GitHub repo
3. Settings → Deploy:
   - Start Command: `bundle exec sidekiq -q critical -q default -q low -q mongo`
4. Copy all environment variables from the main service

#### RPush Service (Push Notifications)

If you need push notifications:

1. New → Empty Service
2. Settings → Source → Connect to same GitHub repo
3. Settings → Deploy:
   - Start Command: `bundle exec rpush start -f`
4. Add environment variable: `INITIALIZE_RPUSH_APPS=true`
5. Copy required environment variables

### 6. Deploy the Application

#### Automatic Deployments

If connected to GitHub, Railway will automatically deploy when you push to your default branch:

```bash
git push origin main
```

#### Manual Deployment

Via CLI:

```bash
railway up
```

Via Dashboard: Click "Deploy" button on your service

---

## Multi-Service Architecture

For production, set up a complete multi-service architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                      Railway Project                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Web App   │  │   Sidekiq   │  │   AnyCable Server   │  │
│  │   (Rails)   │  │   Worker    │  │   (WebSockets)      │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│         │                │                    │              │
│         └────────────────┼────────────────────┘              │
│                          │                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐ │
│  │    MySQL    │  │    Redis    │  │     Elasticsearch    │ │
│  │   (8.0)     │  │   (7.x)     │  │       (7.9)          │ │
│  └─────────────┘  └─────────────┘  └──────────────────────┘ │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐                           │
│  │   MongoDB   │  │  Memcached  │                           │
│  │   (3.6+)    │  │   (optional)│                           │
│  └─────────────┘  └─────────────┘                           │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Service Configuration Templates

#### Web Application (`railway.toml`)

```toml
[build]
builder = "nixpacks"
buildCommand = "npm install && npm run build && bundle install"

[deploy]
startCommand = "bundle exec rails db:migrate && bundle exec puma -C config/puma.rb"
healthcheckPath = "/health"
healthcheckTimeout = 300
numReplicas = 2
```

#### Sidekiq Worker (`railway.toml` - separate file or service config)

Configure in the Railway dashboard:

```
Start Command: bundle exec sidekiq -q critical -q default -q low -q mongo
```

#### AnyCable RPC Service

```
Start Command: bundle exec anycable
```

Environment variables:

```bash
ANYCABLE_RPC_HOST=0.0.0.0:50051
ANYCABLE_REDIS_URL=${{Redis.REDIS_URL}}/4
```

#### AnyCable WebSocket Server

Deploy `anycable-go` as a Docker service:

1. New → Docker Image
2. Image: `anycable/anycable-go:1.4`
3. Environment variables:
   ```bash
   ANYCABLE_HOST=0.0.0.0
   ANYCABLE_PORT=8080
   ANYCABLE_RPC_HOST=${{AnyCableRPC.RAILWAY_PRIVATE_DOMAIN}}:50051
   ANYCABLE_REDIS_URL=${{Redis.REDIS_URL}}/4
   ANYCABLE_SECRET=your-anycable-secret
   ```

---

## Production Considerations

### Custom Domains

1. Go to your web service settings
2. Settings → Networking → Domains
3. Add your custom domain
4. Configure DNS:
   - CNAME: `your-project.railway.app`
   - Or use Railway's provided DNS records

Railway automatically provisions SSL certificates.

### Scaling

Railway supports horizontal scaling:

```toml
[deploy]
numReplicas = 3
```

Or via dashboard: Service Settings → Scaling → Number of Replicas

### Private Networking

All Railway services can communicate via private networking:

```bash
# Reference other services using internal DNS
DATABASE_HOST=${{MySQL.RAILWAY_PRIVATE_DOMAIN}}
ELASTICSEARCH_HOST=http://${{Elasticsearch.RAILWAY_PRIVATE_DOMAIN}}:9200
```

### Resource Limits

Configure memory and CPU limits in service settings:

- **Web**: 2GB RAM, 2 vCPU
- **Worker**: 2GB RAM, 2 vCPU
- **Database**: Depends on data size

### Health Checks

Create a health check endpoint in your Rails app:

```ruby
# config/routes.rb
get '/health', to: proc { [200, {}, ['OK']] }
```

Configure in `railway.toml`:

```toml
[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 300
```

---

## Monitoring and Maintenance

### Logging

View logs in the Railway dashboard or via CLI:

```bash
# Stream logs
railway logs

# Filter by service
railway logs --service web
```

### Metrics

Railway provides built-in metrics:

1. Click on any service
2. Go to "Metrics" tab
3. View CPU, Memory, Network usage

### External Monitoring

Add external monitoring services:

```bash
# Bugsnag
BUGSNAG_API_KEY=your-key

# New Relic (add to Gemfile if needed)
NEW_RELIC_LICENSE_KEY=your-key
```

### Database Backups

Railway handles automatic MySQL backups for paid plans.

For manual backups:

```bash
# Via Railway CLI
railway run mysqldump -h $DATABASE_HOST -u $DATABASE_USERNAME -p$DATABASE_PASSWORD $DATABASE_NAME > backup.sql
```

### Cron Jobs

Use Railway's cron service for scheduled tasks:

1. New → Cron Service
2. Configure the schedule and command:
   - Schedule: `0 * * * *` (hourly)
   - Command: `bundle exec rails runner "YourTask.perform"`

---

## Troubleshooting

### Build Failures

**Problem**: node_modules or asset compilation issues

```bash
# Clear build cache in Railway dashboard
# Service Settings → Build → Clear Build Cache
```

**Problem**: Bundle install fails with sidekiq-pro

Add to build environment:

```bash
BUNDLE_GEMS__CONTRIBSYS__COM=your-key:x
```

### Runtime Errors

**Problem**: Database connection errors

Check variable references:

```bash
# Correct format for Railway variable references
DATABASE_HOST=${{MySQL.MYSQLHOST}}
```

Verify connection:

```bash
railway run rails console
# In console:
ActiveRecord::Base.connection.execute("SELECT 1")
```

**Problem**: Redis connection errors

```bash
# Check Redis URL format
railway run ruby -e "require 'redis'; puts Redis.new(url: ENV['REDIS_URL']).ping"
```

**Problem**: Elasticsearch index errors

```bash
railway run rails console
# In console:
DevTools.delete_all_indices_and_reindex_all
```

### Memory Issues

**Problem**: Out of memory errors

1. Increase service memory limit in dashboard
2. Reduce Puma workers:
   ```bash
   PUMA_WORKER_PROCESSES=1
   RAILS_MAX_THREADS=3
   ```

### Slow Deployments

**Problem**: Builds taking too long

1. Add a `.railwayignore` file:
   ```
   spec/
   test/
   .git/
   tmp/
   log/
   node_modules/
   ```

2. Use build caching effectively by ordering Dockerfile/nixpacks commands

---

## Cost Estimation

Railway uses a usage-based pricing model (2025 rates: **$20/vCPU-month** and **$10/GB-RAM-month** for continuous usage). Estimated monthly costs for a typical Gumroad setup:

| Resource | Configuration (Average Usage) | Estimated Cost |
|----------|-------------------------------|----------------|
| Web Service | 2 Replicas (Active usage) | ~$30-60 |
| Sidekiq Worker | 2 Replicas (Active usage) | ~$30-60 |
| MySQL | Dedicated Resource (1GB RAM) | ~$10-15 |
| Redis | Shared/Small usage | ~$5-10 |
| MongoDB | Shared/Small usage | ~$5-10 |
| Elasticsearch | Custom Container (1GB RAM) | ~$15-20 |
| Network Egress | $0.05 per GB | Variable |
| **Total** | | **~$95-175/month** |

**Notes**:
- Railway charges by the second for actual CPU/RAM consumption.
- The **Pro Plan ($20/month)** includes $20 of monthly usage credits.
- Costs are significantly lower if resources are idle.
- Egress cost is $0.05/GB.

Railway's pricing can be significantly cheaper than Heroku for similar workloads.

---

## Security Checklist

Before going to production:

- [ ] All API keys are properly set as environment variables
- [ ] Custom domain with SSL is configured
- [ ] Private networking is used for database connections
- [ ] Stripe webhooks point to your Railway domain
- [ ] Error monitoring (Bugsnag) is configured
- [ ] Database backups are enabled
- [ ] Health checks are configured
- [ ] Resource limits are set appropriately
- [ ] Sensitive variables are marked as secrets (not visible in logs)

---

## Comparison: Railway vs Heroku

| Feature | Railway | Heroku |
|---------|---------|--------|
| MySQL Support | Native | Requires add-on |
| Pricing Model | Usage-based | Dyno-based |
| Free Tier | 500 hours/month | Limited (Eco dynos) |
| Auto-scaling | Manual replicas | Requires add-on |
| Deploy Speed | Generally faster | Can be slow |
| Private Networking | Built-in | Requires Private Spaces |
| GitHub Integration | Excellent | Good |
| CLI Experience | Modern | Mature |

---

## Related Documentation

- [Production Environment](../production_environment.md) - Service configuration and requirements
- [Sidekiq](../sidekiq.md) - Background job guidelines and troubleshooting
- [Testing](../testing.md) - Testing purchases and payment flows
- [Deploying (Internal)](../deploying.md) - Internal Nomad/AWS deployment (for reference)

---

## Next Steps

1. Set up custom domains and verify SSL
2. Configure Stripe webhooks with your Railway URL
3. Set up monitoring and alerting
4. Configure email delivery and verify sender domains
5. Test the complete purchase flow
6. Set up automated backups
7. Configure cron jobs for scheduled tasks
8. Document your deployment configuration for your team
