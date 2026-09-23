# Localized School Management API

## Run infrastructure

```bash
docker compose up -d
```

## Install and generate Prisma client

```bash
npm install
npx prisma generate
npx prisma migrate dev --name init
npm run start:dev
```

API base:

```text
http://localhost:3000/api
```

Health:

```text
GET /api/health
```

Authentication:

```text
POST /api/auth/login
```

Teacher:

```text
GET /api/teacher/students
POST /api/attendance/sync
POST /api/grades
```

Parent:

```text
GET /api/parent/children
GET /api/parent/students/:studentId/invoices
GET /api/invoices/:invoiceId/receipt.pdf
```

## Important

Create the first school, role, users, academic year and students through a controlled seed/admin process before production.

Do not use the development JWT secret or database password in production.
