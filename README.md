## How to run

```bash
# Use Node.js 22 and make sure Docker is running
npm install
docker compose -f infra/docker/docker-compose.yml up -d
cp .env.example .env
# Edit .env: set NEXTAUTH_SECRET and a 64-character hex ENCRYPTION_KEY
npm run db:generate
npm run db:migrate
npm run dev

# In a second terminal, start the background worker
npm run worker
```