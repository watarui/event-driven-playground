# CQRS/ES Monitor Dashboard

A modern, real-time monitoring dashboard for CQRS Event Sourcing systems built with Next.js, TypeScript, and Effect-ts.

## Features

### 📊 Monitoring Pages

1. **SAGA Monitor** (`/sagas`)
   - Real-time SAGA execution tracking
   - Status visualization (in-progress, completed, failed, compensated)
   - Step-by-step execution details
   - Error tracking and compensation status

2. **Event Store** (`/events`)
   - Live event stream visualization
   - Event filtering by type
   - Event data and metadata inspection
   - Global sequence tracking

3. **PubSub Monitor** (`/pubsub`)
   - Real-time message flow visualization
   - Topic-based message tracking
   - Message throughput statistics
   - Connection status monitoring

4. **Command History** (`/commands`)
   - Command execution history
   - Response time analytics
   - Success/failure rate tracking
   - Command distribution charts

5. **Query Analytics** (`/queries`)
   - Query performance metrics
   - Cache hit rate visualization
   - Response time analysis
   - Query pattern detection

6. **System Topology** (`/topology`)
   - Interactive service dependency graph
   - Real-time health monitoring
   - Service latency and throughput metrics
   - Visual flow of data between services

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Runtime**: Bun
- **Styling**: Tailwind CSS
- **State Management**: Effect-ts
- **GraphQL Client**: Apollo Client
- **Charts**: Recharts
- **Flow Diagrams**: React Flow
- **Linting**: Biome

## Getting Started

### Prerequisites

- Bun installed (or Node.js)
- Docker (optional, for containerized deployment)

### Installation

```bash
# Install dependencies
bun install

# Run development server
bun run dev

# Build for production
bun run build

# Start production server
bun start
```

### Environment Variables

Copy the environment template and create your local configuration:

```bash
# For local development
cp .env.example .env.local

# For production deployment
cp .env.example .env.production
```

Edit the `.env.local` file with your local settings:

```env
NEXT_PUBLIC_GRAPHQL_ENDPOINT=http://localhost:4000/graphql
NEXT_PUBLIC_WS_ENDPOINT=ws://localhost:4000/graphql
```

### Docker Deployment

```bash
# Build and run with Docker Compose
docker compose up monitor-dashboard
```

## Architecture

### Effect-ts Integration

The application uses Effect-ts for:
- Service layer abstraction
- Error handling and retries
- Stream processing for real-time data
- Dependency injection

### GraphQL Integration

- Queries for fetching data
- Mutations for triggering actions
- Subscriptions for real-time updates

### Real-time Features

- WebSocket connections for live data
- Auto-refresh mechanisms
- Event stream processing
- Push notifications for critical events

## Development

### Project Structure

```
frontend/
├── app/              # Next.js app router pages
├── components/       # Reusable UI components
├── hooks/           # Custom React hooks
├── lib/             # Utilities and configurations
│   ├── effects/     # Effect-ts modules
│   ├── graphql/     # GraphQL queries/mutations
│   └── apollo-client.ts
├── public/          # Static assets
└── package.json
```

### Key Commands

```bash
# Format code
bun run format

# Lint code
bun run lint

# Type check
bun tsc --noEmit
```

## Future Enhancements

- [ ] Direct database connections for historical data
- [ ] Prometheus/Grafana integration
- [ ] Jaeger tracing visualization
- [ ] Alert configuration UI
- [ ] Export functionality for reports
- [ ] Mobile responsive improvements

## License

MIT