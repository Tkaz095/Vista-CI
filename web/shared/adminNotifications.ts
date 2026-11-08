export interface NotificationRecipient {
  uid: string
  displayName: string
}

export interface NotificationRecipientsPage {
  recipients: NotificationRecipient[]
  nextCursor: string | null
}

export interface AdminNotificationDraft {
  requestId: string
  uid: string
  title: string
  body: string
}

export interface AdminNotificationResult {
  requestId: string
  notificationId: string
  uid: string
  state: 'sending' | 'completed'
  devices: number
  sent: number
  failed: number
  uncertain: number
}
