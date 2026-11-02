import {
  collection,
  deleteDoc,
  doc,
  getDocsFromServer,
  limit,
  query,
  runTransaction,
  serverTimestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore'
import { auth, db } from '../../lib/firebase'
import type { GitHubRepo } from '../github/githubService'
export interface PersonalWorkspace {
  id: string
  name: string
  description: string
  status: 'active' | 'deleting'
}
export interface WorkspaceRepo extends GitHubRepo {
  displayName: string
  note: string
}
export const workspaceQuery = (uid: string) =>
  query(collection(db, 'workspaces'), where('ownerUid', '==', uid))
export const repoQuery = (id: string) => collection(db, 'workspaces', id, 'repositories')
function identity(uid: string) {
  if (auth.currentUser?.uid !== uid) throw new Error('Phiên tài khoản đã thay đổi. Đăng nhập lại.')
}
function fields(name: string, description: string) {
  name = name.trim()
  description = description.trim()
  if (!name || name.length > 100 || description.length > 1000)
    throw new Error('Tên cần 1–100 ký tự; mô tả tối đa 1000 ký tự.')
  return { name, description }
}
function repoData(repo: GitHubRepo) {
  return {
    githubRepositoryId: repo.id,
    fullName: repo.fullName,
    htmlUrl: repo.htmlUrl,
    defaultBranch: repo.defaultBranch,
    private: repo.private,
    displayName: Array.from(repo.fullName).slice(0, 100).join(''),
    note: '',
    addedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }
}
export async function createWorkspace(
  uid: string,
  name: string,
  description: string,
  repos: GitHubRepo[],
): Promise<string> {
  identity(uid)
  if (repos.length > 100) throw new Error('Chọn tối đa 100 repo mỗi lần; có thể thêm tiếp sau khi tạo.')
  const reference = doc(collection(db, 'workspaces'))
  const batch = writeBatch(db)
  batch.set(reference, {
    ...fields(name, description),
    ownerUid: uid,
    status: 'active',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  })
  for (const repo of repos) batch.set(doc(reference, 'repositories', repo.id), repoData(repo))
  await batch.commit()
  return reference.id
}
export async function editWorkspace(uid: string, id: string, name: string, description: string) {
  identity(uid)
  await updateDoc(doc(db, 'workspaces', id), { ...fields(name, description), updatedAt: serverTimestamp() })
}
export async function addRepository(uid: string, workspaceId: string, repo: GitHubRepo) {
  identity(uid)
  const reference = doc(db, 'workspaces', workspaceId, 'repositories', repo.id)
  await runTransaction(db, async (transaction) => {
    const existing = await transaction.get(reference)
    if (!existing.exists()) transaction.set(reference, repoData(repo))
  })
}
export async function editRepository(
  uid: string,
  workspaceId: string,
  id: string,
  displayName: string,
  note: string,
) {
  identity(uid)
  displayName = displayName.trim()
  note = note.trim()
  if (!displayName || displayName.length > 100 || note.length > 1000)
    throw new Error('Nhãn cần 1–100 ký tự; ghi chú tối đa 1000 ký tự.')
  await updateDoc(doc(db, 'workspaces', workspaceId, 'repositories', id), {
    displayName,
    note,
    updatedAt: serverTimestamp(),
  })
}
export async function removeRepository(uid: string, workspaceId: string, id: string) {
  identity(uid)
  await deleteDoc(doc(db, 'workspaces', workspaceId, 'repositories', id))
}
export async function removeWorkspace(uid: string, id: string) {
  identity(uid)
  const reference = doc(db, 'workspaces', id)
  await runTransaction(db, async (transaction) => {
    const snapshot = await transaction.get(reference)
    if (!snapshot.exists()) return
    if (snapshot.data().ownerUid !== uid) throw new Error('Bạn không sở hữu workspace này.')
    transaction.update(reference, { status: 'deleting', updatedAt: serverTimestamp() })
  })
  for (;;) {
    identity(uid)
    const children = await getDocsFromServer(query(repoQuery(id), limit(100)))
    if (children.empty) break
    const batch = writeBatch(db)
    children.docs.forEach((child) => batch.delete(child.ref))
    await batch.commit()
  }
  identity(uid)
  await deleteDoc(reference)
}
export function workspaceError(cause: unknown): string {
  const code = typeof cause === 'object' && cause !== null && 'code' in cause ? String(cause.code) : ''
  if (code === 'permission-denied')
    return 'Chưa có quyền thao tác. Publish Rules ownerUid mới trong đúng project vista-ci, database (default).'
  if (code === 'unavailable') return 'Không kết nối được Firestore. Kiểm tra mạng rồi thử lại.'
  return cause instanceof Error && !code
    ? cause.message
    : 'Chưa hoàn tất thao tác. Tải lại dữ liệu và thử lại.'
}
