import { GoogleAuth } from 'google-auth-library'

// Analytics needs its own OAuth scope, beyond Firebase Admin's default scopes.
// Reuse the service-account identity, never send its key to the browser.
export async function analyticsAccessToken(): Promise<string> {
  const email = process.env.FIREBASE_CLIENT_EMAIL
  const key = process.env.FIREBASE_PRIVATE_KEY
  if (!!email !== !!key) throw new Error('Incomplete service-account credentials')
  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/analytics.readonly'],
    credentials: email && key ? { client_email: email, private_key: key.replace(/\\n/g, '\n') } : undefined,
  })
  const token = await auth.getAccessToken()
  if (!token) throw new Error('No Analytics access token')
  return token
}
