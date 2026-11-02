import type { CSSProperties } from 'react'

type IconName =
  | 'activity'
  | 'check'
  | 'cross'
  | 'clock'
  | 'pause'
  | 'branch'
  | 'commit'
  | 'external'
  | 'refresh'
  | 'filter'
  | 'repo'
  | 'workspace'
  | 'user'
  | 'arrow'
  | 'alert'
const paths: Record<IconName, string> = {
  activity: 'M3 12h4l3-8 4 16 3-8h4',
  check: 'm6 12 4 4 8-8',
  cross: 'm7 7 10 10M17 7 7 17',
  clock: 'M12 8v5l3 2M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',
  pause: 'M9 7v10M15 7v10',
  branch:
    'M6 6v12M18 6v3a6 6 0 0 1-6 6H6M8 4a2 2 0 1 1-4 0 2 2 0 0 1 4 0M8 20a2 2 0 1 1-4 0 2 2 0 0 1 4 0M20 4a2 2 0 1 1-4 0 2 2 0 0 1 4 0',
  commit: 'M3 12h5m8 0h5M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  external: 'M14 3h7v7m0-7L10 14M10 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-5',
  refresh: 'M20 7v5h-5M4 17v-5h5M6 6a8 8 0 0 1 13 3M5 15a8 8 0 0 0 13 3',
  filter: 'M4 7h16M7 12h10M10 17h4',
  repo: 'M5 3h14v18l-7-4-7 4V3m4 0v10l3-2 3 2V3',
  workspace: 'M3 4h7v7H3V4m11 0h7v7h-7V4M3 15h7v6H3v-6m11 0h7v6h-7v-6',
  user: 'M20 21v-2a7 7 0 0 0-14 0v2M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  arrow: 'M5 12h14m-5-5 5 5-5 5',
  alert: 'M12 8v5m0 3h.01M10 3 2 18a2 2 0 0 0 2 3h16a2 2 0 0 0 2-3L14 3a2 2 0 0 0-4 0',
}
export function UiIcon({
  name,
  className = '',
  style,
}: {
  name: IconName
  className?: string
  style?: CSSProperties
}) {
  return (
    <svg
      className={`ui-icon ${className}`}
      style={style}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[name]} />
    </svg>
  )
}
