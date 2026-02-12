# PitchInsights Backend

## Smoke test

```bash
npm run build
node dist/main.js
```

In a second terminal:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/
curl http://localhost:3000/bootstrap
```
