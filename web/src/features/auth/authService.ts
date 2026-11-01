import { GithubAuthProvider, linkWithPopup, onAuthStateChanged, signInWithEmailAndPassword, signInWithPopup, signOut } from 'firebase/auth'
import { doc, onSnapshot, runTransaction } from 'firebase/firestore'
import type { User } from 'firebase/auth'
import { auth, db } from '../../lib/firebase'

export interface VistaProfile {
  uid: string
  email: string
  displayName: string
  role: 'user'
}

export type AuthSession =
  | { status: 'initializing' }
  | { status: 'signed_out' }
  | { status: 'checking_profile' }
  | { status: 'ready'; profile: VistaProfile }
  | { status: 'blocked' | 'error'; message: string }

export function authErrorMessage(error: unknown): string {
  const code = typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : ''
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
    case 'auth/invalid-email':
      return 'Email hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.'
    case 'auth/too-many-requests':
      return 'Có quá nhiều lần thử đăng nhập. Vui lòng thử lại sau.'
    case 'auth/network-request-failed':
      return 'Không kết nối được dịch vụ đăng nhập. Kiểm tra mạng rồi thử lại.'
    case 'auth/user-disabled':
      return 'Tài khoản chưa được phép đăng nhập. Vui lòng liên hệ người quản trị.'
    case 'auth/operation-not-allowed':
      return 'Phương thức đăng nhập này chưa được bật trên Firebase.'
    case 'auth/unauthorized-domain':
      return 'Tên miền hiện tại chưa được cho phép đăng nhập. Vui lòng liên hệ người quản trị.'
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request':
      return 'Bạn đã hủy đăng nhập GitHub. Có thể thử lại khi sẵn sàng.'
    case 'auth/popup-blocked':
      return 'Trình duyệt đã chặn cửa sổ GitHub. Cho phép popup cho trang Vista rồi thử lại.'
    case 'auth/account-exists-with-different-credential':
    case 'auth/email-already-in-use':
      return 'Email này đã có tài khoản Vista. Đăng nhập bằng Email/Password, mở Tài khoản và chọn Liên kết GitHub để giữ UID hiện có.'
    case 'auth/credential-already-in-use':
      return 'GitHub này đã gắn với một tài khoản Vista khác. Không thể tự gộp hai tài khoản.'
    case 'auth/provider-already-linked':
      return 'Tài khoản Vista này đã liên kết GitHub.'
    case 'auth/requires-recent-login':
      return 'Hãy đăng xuất và đăng nhập lại trước khi liên kết GitHub.'
    case 'auth/no-current-user':
      return 'Phiên đã kết thúc. Đăng nhập lại trước khi liên kết GitHub.'
    case 'auth/invalid-oauth-client-id':
    case 'auth/invalid-oauth-provider':
      return 'Cấu hình GitHub OAuth chưa hợp lệ. Kiểm tra provider và callback URL trên Firebase/GitHub.'
    default:
      return 'Chưa thể hoàn tất thao tác đăng nhập. Vui lòng thử lại.'
  }
}

// Signing in establishes identity only. observeSession gates access on the server profile.
export async function login(email: string, password: string): Promise<void> {
  await signInWithEmailAndPassword(auth, email.trim(), password)
}

// Firebase handles OAuth; access tokens and secrets are never persisted by Vista.
// Repository access will use a separate GitHub App connection.
export async function loginWithGitHub(): Promise<void> {
  await signInWithPopup(auth, new GithubAuthProvider())
}

export function hasGitHubLink(): boolean {
  return auth.currentUser?.providerData.some(provider => provider.providerId === 'github.com') ?? false
}

export async function linkGitHub(): Promise<void> {
  const user = auth.currentUser
  if (!user) throw { code: 'auth/no-current-user' }
  await linkWithPopup(user, new GithubAuthProvider())
}

export function logout(): Promise<void> {
  return signOut(auth)
}

// Create missing profiles and normalize legacy roles to user. Activation and
// other existing fields are never changed. Concurrent clients re-read on retry.
async function ensureOwnProfile(user: User, current: () => boolean): Promise<void> {
  const reference = doc(db, 'users', user.uid)
  const name = user.displayName?.trim() || user.email?.split('@')[0]?.trim() || 'Thành viên Vista'
  await runTransaction(db, async transaction => {
    if (!current()) return
    const existing = await transaction.get(reference)
    if (!current()) return
    if (existing.exists()) {
      if (existing.data().isActive === true && existing.data().role !== 'user') {
        transaction.update(reference, { role: 'user' })
      }
      return
    }
    transaction.set(reference, {
      displayName: Array.from(name).slice(0, 100).join(''),
      role: 'user',
      isActive: true,
    })
  })
}

// A new auth identity invalidates all pending profile callbacks. Every subscription is
// removed on logout/unmount; server-confirmed profile changes can revoke UI access.
export function observeSession(onChange: (session: AuthSession) => void): () => void {
  let generation = 0
  let disposed = false
  let stopProfile: (() => void) | undefined
  let profileDeadline: ReturnType<typeof setTimeout> | undefined
  const clearProfile = () => {
    stopProfile?.()
    stopProfile = undefined
    clearTimeout(profileDeadline)
    profileDeadline = undefined
  }
  onChange({ status: 'initializing' })
  const stopAuth = onAuthStateChanged(auth, (user) => {
    const currentGeneration = ++generation
    clearProfile()
    if (!user) {
      onChange({ status: 'signed_out' })
      return
    }
    const current = () => !disposed && generation === currentGeneration
    let provisioningAttempted = false
    const waitForServer = () => {
      onChange({ status: 'checking_profile' })
      if (!profileDeadline) profileDeadline = setTimeout(() => {
        if (current()) onChange({ status: 'error', message: 'Chưa xác minh được hồ sơ với máy chủ. Kiểm tra mạng và thử lại.' })
      }, 15000)
    }
    waitForServer()
    stopProfile = onSnapshot(doc(db, 'users', user.uid), { includeMetadataChanges: true }, (snapshot) => {
      if (!current()) return
      if (snapshot.metadata.fromCache || snapshot.metadata.hasPendingWrites) {
        waitForServer()
        return
      }
      const data = snapshot.data()
      if (!snapshot.exists() || (data?.isActive === true && data.role !== 'user')) {
        if (provisioningAttempted) return
        provisioningAttempted = true
        waitForServer()
        void ensureOwnProfile(user, current).catch(error => {
          if (!current()) return
          clearTimeout(profileDeadline)
          profileDeadline = undefined
          onChange({ status: 'error', message: error?.code === 'permission-denied'
            ? 'Chưa được phép tạo hồ sơ Vista. Hãy publish Firestore Rules mới cho phép tạo hồ sơ User và chuyển vai trò cũ về user, rồi bấm Kiểm tra lại.'
            : 'Chưa khởi tạo được hồ sơ Vista. Kiểm tra mạng rồi bấm Kiểm tra lại.' })
        })
        return
      }
      clearTimeout(profileDeadline)
      profileDeadline = undefined
      if (!data || data.isActive !== true) {
        onChange({ status: 'blocked', message: 'Hồ sơ chưa được phép sử dụng Vista. Vui lòng liên hệ người quản trị.' })
        return
      }
      if (data.role !== 'user') {
        onChange({ status: 'blocked', message: 'Chưa chuyển được hồ sơ về user. Bấm Kiểm tra lại sau khi cập nhật Rules.' })
        return
      }
      onChange({ status: 'ready', profile: {
        uid: user.uid,
        email: user.email ?? '',
        displayName: typeof data.displayName === 'string' ? data.displayName.trim() : '',
        role: data.role,
      } })
    }, (error) => {
      if (!current()) return
      clearTimeout(profileDeadline)
      profileDeadline = undefined
      onChange({ status: 'error', message: error.code === 'permission-denied'
        ? 'Firebase từ chối đọc hồ sơ cá nhân (permission-denied). Kiểm tra Rules ở project vista-ci, database (default): phải cho tài khoản đã đăng nhập đọc document users của chính mình, kể cả khi document chưa tồn tại.'
        : 'Không tải được hồ sơ Vista. Kiểm tra mạng rồi thử lại.' })
    })
  }, (error) => {
    ++generation
    clearProfile()
    if (!disposed) onChange({ status: 'error', message: authErrorMessage(error) })
  })
  return () => {
    disposed = true
    ++generation
    stopAuth()
    clearProfile()
  }
}
