# Visitor Counter Analytics App

A minimal LAMP stack application that tracks website visitors and displays analytics.

## Features

- Tracks visitor IP addresses, user agents, and visit times
- Displays total visits, unique visitors, and today's visits
- Automatic database table creation
- Responsive web interface

## Quick Start

1. Build and run with Docker Compose:
```bash
docker-compose up --build
```

2. Access the application at: http://localhost:8080

## Architecture

- **Linux**: Container base OS
- **Apache**: Web server (PHP 8.1-Apache image)
- **MySQL**: Database (MySQL 8.0)
- **PHP**: Application logic with PDO for database connectivity

## Database Schema

The application automatically creates a `visitors` table with:
- `id`: Auto-increment primary key
- `ip_address`: Visitor IP address
- `user_agent`: Browser/client information
- `visit_time`: Timestamp of visit
- `page_url`: Requested page URL