# Localized School Management — Full Stack

Structure:

- `mobile/` Flutter Android + PWA
- `backend/` NestJS API + Prisma + PostgreSQL
- Redis included through Docker Compose

Start backend:

```bash
cd backend
docker compose up -d
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run start:dev
```

Then point Flutter to:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

For a physical Android phone, replace `10.0.2.2` with the LAN IP of the computer running NestJS.
