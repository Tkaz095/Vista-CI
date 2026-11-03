import { defineSecret, defineString } from 'firebase-functions/params'

export const appOrigin = defineString('VISTA_APP_ORIGIN', {
  default: 'https://vista-ci.web.app',
  description: 'Origin used by the web app and GitHub OAuth callback.',
})
export const githubClientId = defineString('GITHUB_CLIENT_ID', {
  description: 'GitHub OAuth App client ID; keep the existing OAuth App.',
})
export const githubClientSecret = defineSecret('GITHUB_CLIENT_SECRET')
export const tokenEncryptionKey = defineSecret('GITHUB_TOKEN_ENCRYPTION_KEY')
