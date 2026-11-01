export type RunStatus = 'queued' | 'in_progress' | 'success' | 'failure' | 'cancelled'
export type DiagnosisKind = 'code' | 'transient' | 'configuration' | 'unknown'

export interface Repository {
  id: string
  name: string
  description: string
}

export interface Workspace {
  id: string
  name: string
  description: string
  repositories: Repository[]
}

export interface Diagnosis {
  kind: DiagnosisKind
  summary: string
  evidence: string
  location?: string
  suggestions: string[]
}

export interface WorkflowRun {
  key: string
  workspaceId: string
  repositoryId: string
  workflow: string
  runId: string
  attempt: number
  branch: string
  sha: string
  status: RunStatus
  startedAt: string
  duration: string
  triggerActor: string
  pullRequest?: { number: number; author: string }
  steps: { name: string; status: RunStatus }[]
  log: string[]
  exampleDiagnosis?: Diagnosis
}

export type CommandAction = 'dispatch' | 'rerun' | 'create_issue' | 'comment_pr'

export interface CommandDraft {
  workspaceId: string
  repositoryId: string
  runKey: string
  action: CommandAction
  body: string
}

export interface AuditEntry {
  id: string
  workspaceId: string
  actor: string
  action: string
  target: string
  at: string
  outcome: 'preview'
}

// Integration contract: implement on a trusted backend after its approach is agreed.
// UI drafts cannot be treated as accepted GitHub commands or persisted audit evidence.
export interface WorkspaceGateway {
  listWorkspaces(): Promise<Workspace[]>
  listRuns(workspaceId: string): Promise<WorkflowRun[]>
  analyzeRun(runKey: string): Promise<Diagnosis>
  submitCommand(command: CommandDraft, requestId: string): Promise<{ requestId: string }>
}
