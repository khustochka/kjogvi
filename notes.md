# Kjógvi Project Analysis

## Overview
- Phoenix umbrella project focused on birding/ornithology
- Multiple apps: kjogvi, kjogvi_web, ornithologue, ornitho_web
- Uses PostgreSQL database (port 5498)
- Requires setup for admin user on first run

## Apps Structure
1. **kjogvi** - Core application logic
2. **kjogvi_web** - Main web interface  
3. **ornithologue** - Ornithological taxonomy system
4. **ornitho_web** - Taxonomy web interface

## Database Setup
- PostgreSQL via Docker Compose
- Migration setup required on first run
- Test environment needs separate setup

## Next Steps
- Explore each app's functionality
- Check current state and what features exist
- Understand the data models and schemas
- Determine what we want to build or modify
