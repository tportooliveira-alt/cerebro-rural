import type { ReactNode } from 'react'

export function Rotulo({ children }: { children: ReactNode }) {
  return <span className="rotulo">{children}</span>
}

export function Cartao({ children, className = '' }: { children: ReactNode; className?: string }) {
  return <section className={`bg-panel border border-line rounded-sm ${className}`}>{children}</section>
}

const CORES = {
  ok: 'text-ok bg-okbg', warn: 'text-warn bg-warnbg', bad: 'text-bad bg-badbg',
  neutro: 'text-ink2 bg-panel2', accent: 'text-accent bg-accentsoft',
} as const

export function Selo({ cor = 'neutro', children }: { cor?: keyof typeof CORES; children: ReactNode }) {
  return (
    <span className={`${CORES[cor]} font-mono text-[.64rem] font-semibold uppercase tracking-wider px-2 py-[3px] rounded-sm whitespace-nowrap`}>
      {children}
    </span>
  )
}

export function Botao({ children, onClick, variante = 'normal', type = 'button', disabled, className = '' }: {
  children: ReactNode; onClick?: () => void; variante?: 'normal' | 'primario' | 'discreto'; type?: 'button' | 'submit'; disabled?: boolean; className?: string
}) {
  const base = 'font-mono text-[.72rem] uppercase tracking-wider px-3 py-2 rounded-sm cursor-pointer disabled:opacity-50 disabled:cursor-default min-h-[44px] sm:min-h-0'
  const v = variante === 'primario'
    ? 'bg-accent text-bg border border-accent'
    : variante === 'discreto' ? 'bg-transparent text-ink2 border border-transparent hover:text-ink' : 'bg-panel text-ink border border-line'
  return <button type={type} onClick={onClick} disabled={disabled} className={`${base} ${v} ${className}`}>{children}</button>
}

/** Barras horizontais por categoria. A maior barra define a escala; todo rótulo mostra o valor real. */
export function Barras({ itens, cor = 'accent' }: { itens: Array<{ nome: string; valor: number; sub?: string }>; cor?: 'accent' | 'bad' | 'ok' }) {
  const max = Math.max(...itens.map((i) => i.valor), 1)
  const fundo = cor === 'bad' ? 'var(--bad)' : cor === 'ok' ? 'var(--ok)' : 'var(--accent)'
  return (
    <ul className="list-none p-0 m-0 flex flex-col gap-3">
      {itens.map((i) => (
        <li key={i.nome} className="grid gap-1">
          <div className="flex justify-between items-baseline gap-3">
            <span className="text-[.95rem]">{i.nome}</span>
            <span className="num text-[.95rem] font-semibold">{i.sub}</span>
          </div>
          <div className="h-[6px] bg-panel2 rounded-full overflow-hidden">
            <div className="h-full rounded-full" style={{ width: `${Math.max(2, (i.valor / max) * 100)}%`, background: fundo }} />
          </div>
        </li>
      ))}
    </ul>
  )
}

export function Vazio({ children }: { children: ReactNode }) {
  return <p className="text-ink2 text-[.95rem] m-0">{children}</p>
}
