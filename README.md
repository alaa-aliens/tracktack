# Tamm (formerly TrackTack)
Invoices, expenses and cash tracking. Static site + Supabase backend.

Files:
- index.html  – the app
- config.js   – Supabase URL + publishable key
- schema.sql  – run once in Supabase SQL editor
- vendor/     – Supabase and html2canvas, served from this site (pinned versions, no outside CDN)
- sql/01-audit.sql     – read-only health check of the live database
- sql/02-hardening.sql – role-based rules, version history, safer shop codes, photo limits

Note: schema.sql is the original setup and is older than the live database (invites, roles).
