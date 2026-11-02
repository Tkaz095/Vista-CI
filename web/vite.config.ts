import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import githubJobLog from './api/github-job-log'
import githubSession from './api/github-session'
import githubData from './api/github-data'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  for (const name of [
    'VISTA_APP_ORIGIN',
    'GITHUB_CLIENT_ID',
    'GITHUB_CLIENT_SECRET',
    'GITHUB_TOKEN_ENCRYPTION_KEY',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_PRIVATE_KEY',
    'GOOGLE_APPLICATION_CREDENTIALS',
  ]) {
    if (!process.env[name] && env[name]) process.env[name] = env[name]
  }
  const routes = {
    '/api/github-job-log': githubJobLog,
    '/api/github-session': githubSession,
    '/api/github-data': githubData,
  }
  return {
    server: { port: 5173, strictPort: true },
    plugins: [
      react(),
      {
        name: 'vista-github-api',
        configureServer(server) {
          server.middlewares.use((req, res, next) => {
            const handler = routes[req.url?.split('?')[0] as keyof typeof routes]
            if (handler) {
              void handler(req, res)
              return
            }
            next()
          })
        },
      },
    ],
  }
})
