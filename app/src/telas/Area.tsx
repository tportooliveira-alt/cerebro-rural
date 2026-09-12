import { useMemo, useState } from 'react'
import type { Estado } from '../estado/store'
import { Cartao, Rotulo, Selo, Vazio } from '../componentes'
import { brl, celula, dataBR, num } from '../formato'
import type { Area as TArea } from '../tomada'
import { NOME_AREA } from './Hoje'

export function LinhaOrigem({ estado, arquivoId, linha, fechar }: { estado: Estado; arquivoId: string; linha: number; fechar: () => void }) {
  const arq = estado.arquivos.find((a) => a.id === arquivoId)
  const cab = arq?.grade[0] ?? []
  const alvo = arq?.grade.find((_, i) => i > 0 && arq.linhaCabecalho + i === linha) ?? arq?.grade[1]
  return (
    <div className="fixed inset-0 z-40 bg-black/50 flex items-end sm:items-center justify-center p-0 sm:p-5" onClick={fechar}>
      <div className="bg-panel border border-line rounded-t-lg sm:rounded-sm w-full max-w-2xl max-h-[85vh] overflow-auto" onClick={(e) => e.stopPropagation()}>
        <div className="p-5 border-b border-line sticky top-0 bg-panel">
          <Rotulo>linha de origem</Rotulo>
          <h3 className="text-lg mt-1">{arq?.nome} · {arq?.aba} · linha {linha}</h3>
        </div>
        <div className="p-5">
          {alvo ? (
            <dl className="grid grid-cols-[minmax(0,1fr)_minmax(0,1.4fr)] gap-x-4 gap-y-2 m-0">
              {cab.map((c, i) => (
                <div key={i} className="contents">
                  <dt className="rotulo truncate">{celula(c) || `coluna ${i + 1}`}</dt>
                  <dd className="m-0 text-[.95rem] break-words">{celula(alvo[i]) || <span className="text-ink2">—</span>}</dd>
                </div>
              ))}
            </dl>
          ) : <Vazio>A linha original não está mais disponível nesta sessão.</Vazio>}
          <p className="text-ink2 text-[.85rem] mt-5 mb-0">Lido em {arq ? dataBR(arq.lidoEm.slice(0, 10)) : '—'} · arquivo guardado com hash {arq?.hash.slice(0, 12)}…</p>
        </div>
      </div>
    </div>
  )
}

export function TelaFinancas({ estado, mes }: { estado: Estado; mes: string }) {
  const [origem, setOrigem] = useState<{ arquivoId: string; linha: number } | null>(null)
  const [filtro, setFiltro] = useState('')
  const linhas = useMemo(() => {
    const f = filtro.trim().toLowerCase()
    return estado.lancamentos
      .filter((l) => l.data.startsWith(mes))
      .filter((l) => !f || l.descricao.toLowerCase().includes(f) || (l.categoria ?? '').toLowerCase().includes(f) || (l.contraparte ?? '').toLowerCase().includes(f))
      .sort((a, b) => b.data.localeCompare(a.data))
  }, [estado.lancamentos, mes, filtro])
  const total = linhas.reduce((s, l) => s + (l.neutro ? 0 : l.tipo === 'ENTRADA' ? l.valor : -l.valor), 0)

  return (
    <div className="grid gap-4">
      <div className="flex gap-3 items-center flex-wrap">
        <input value={filtro} onChange={(e) => setFiltro(e.target.value)} placeholder="Buscar descrição, categoria, quem…"
          className="flex-1 min-w-[200px] bg-panel border border-line rounded-sm px-3 py-2 text-[.95rem] text-ink" />
        <span className="rotulo">{linhas.length} lançamentos · resultado {brl(total)}</span>
      </div>
      <Cartao className="overflow-x-auto">
        <table className="w-full border-collapse text-[.92rem] min-w-[600px]">
          <thead>
            <tr className="text-left border-b border-line">
              {['Data', 'Descrição', 'Categoria', 'Fonte', 'Valor', ''].map((h) => (
                <th key={h} className="rotulo font-semibold p-3 whitespace-nowrap">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {linhas.map((l) => (
              <tr key={l.hashLinha} className="border-b border-line last:border-0">
                <td className="p-3 num whitespace-nowrap">{dataBR(l.data)}</td>
                <td className="p-3">{l.descricao}{l.contraparte && l.contraparte !== l.descricao && <span className="text-ink2"> · {l.contraparte}</span>}</td>
                <td className="p-3">{l.neutro ? <Selo>{l.categoria}</Selo> : l.categoria ? <span className="text-ink2">{l.categoria}</span> : <Selo cor="warn">sem categoria</Selo>}</td>
                <td className="p-3 text-ink2">{estado.fontes.find((f) => f.id === l.fonteId)?.nome ?? '—'}</td>
                <td className={`p-3 num text-right whitespace-nowrap font-semibold ${l.neutro ? 'text-ink2' : l.tipo === 'ENTRADA' ? 'text-ok' : 'text-bad'}`}>
                  {l.tipo === 'ENTRADA' ? '' : '−'}{brl(l.valor)}
                </td>
                <td className="p-3 text-right">
                  <button onClick={() => setOrigem({ arquivoId: l.arquivoId, linha: l.origem.linha })}
                    className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent whitespace-nowrap">origem</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {linhas.length === 0 && <div className="p-5"><Vazio>Nada neste mês com esse filtro.</Vazio></div>}
      </Cartao>
      {origem && <LinhaOrigem estado={estado} arquivoId={origem.arquivoId} linha={origem.linha} fechar={() => setOrigem(null)} />}
    </div>
  )
}

/** Painéis das outras áreas: mesma forma (resumo, lista, origem), números da área. */
export function TelaArea({ estado, area }: { estado: Estado; area: Exclude<TArea, 'financas'> }) {
  const [origem, setOrigem] = useState<{ arquivoId: string; linha: number } | null>(null)
  const regs = useMemo(() => estado.registros.filter((r) => r.area === area), [estado.registros, area])
  const colunas = useMemo(() => {
    const set = new Set<string>()
    for (const r of regs) for (const k of Object.keys(r.campos)) if (r.campos[k] !== null) set.add(k)
    const ordem = ['brinco', 'lote', 'categoria_animal', 'sexo', 'raca', 'peso_kg', 'arrobas', 'pasto', 'nascimento', 'evento',
      'codigo', 'item', 'unidade', 'quantidade', 'tipo_mov', 'local', 'responsavel', 'custo_unitario', 'minimo', 'estado', 'data']
    return [...set].sort((a, b) => (ordem.indexOf(a) + 1 || 99) - (ordem.indexOf(b) + 1 || 99))
  }, [regs])

  const saldoPorItem = useMemo(() => {
    if (area !== 'estoque' && area !== 'almoxarifado') return null
    const m = new Map<string, { saldo: number; unidade: string; minimo: number }>()
    for (const r of regs) {
      const item = String(r.campos.item ?? ''); if (!item) continue
      const q = Number(r.campos.quantidade) || 0
      const at = m.get(item) ?? { saldo: 0, unidade: String(r.campos.unidade ?? ''), minimo: Number(r.campos.minimo) || 0 }
      at.saldo += r.campos.tipo_mov === 'saida' ? -q : q
      m.set(item, at)
    }
    return [...m].map(([nome, v]) => ({ nome, ...v }))
  }, [regs, area])

  const rotulo = (c: string) => ({
    brinco: 'Brinco', lote: 'Lote', categoria_animal: 'Categoria', sexo: 'Sexo', raca: 'Raça', peso_kg: 'Peso (kg)',
    arrobas: 'Arrobas', pasto: 'Pasto', nascimento: 'Nascimento', evento: 'Evento', codigo: 'Código', item: 'Item',
    unidade: 'Un.', quantidade: 'Qtd', tipo_mov: 'Movimento', local: 'Local', responsavel: 'Responsável',
    custo_unitario: 'Custo un.', minimo: 'Mínimo', estado: 'Estado', data: 'Data', observacao: 'Obs.',
  } as Record<string, string>)[c] ?? c

  const valor = (c: string, v: unknown) => {
    if (v === null || v === undefined || v === '') return <span className="text-ink2">—</span>
    if (c === 'custo_unitario') return brl(Number(v))
    if (c === 'peso_kg' || c === 'arrobas' || c === 'quantidade' || c === 'minimo') return num(Number(v), c === 'quantidade' || c === 'minimo' ? 0 : 1)
    if (c === 'data' || c === 'nascimento') return dataBR(String(v))
    if (c === 'evento' || c === 'tipo_mov') return <Selo cor={String(v) === 'saida' ? 'bad' : String(v) === 'entrada' ? 'ok' : 'neutro'}>{String(v)}</Selo>
    return String(v)
  }

  return (
    <div className="grid gap-4">
      {saldoPorItem && (
        <Cartao className="p-5">
          <Rotulo>saldo por item</Rotulo>
          <ul className="list-none p-0 m-0 mt-3 grid sm:grid-cols-2 gap-x-6 gap-y-2">
            {saldoPorItem.map((i) => (
              <li key={i.nome} className="flex justify-between items-baseline gap-3 border-b border-line pb-2">
                <span className="text-[.95rem]">{i.nome}</span>
                <span className="num whitespace-nowrap">
                  <span className={i.minimo > 0 && i.saldo < i.minimo ? 'text-bad font-semibold' : 'font-semibold'}>{num(i.saldo, 0)}</span>
                  <span className="text-ink2"> {i.unidade}</span>
                  {i.minimo > 0 && <span className="text-ink2 text-[.85rem]"> · mín {num(i.minimo, 0)}</span>}
                </span>
              </li>
            ))}
          </ul>
        </Cartao>
      )}
      <span className="rotulo">{regs.length} registros em {NOME_AREA[area].toLowerCase()}</span>
      <Cartao className="overflow-x-auto">
        <table className="w-full border-collapse text-[.92rem]" style={{ minWidth: Math.max(520, colunas.length * 110) }}>
          <thead>
            <tr className="text-left border-b border-line">
              {colunas.map((c, i) => <th key={c} className={`rotulo font-semibold p-3 whitespace-nowrap ${i === 0 ? 'sticky left-0 bg-panel' : ''}`}>{rotulo(c)}</th>)}
              <th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {regs.map((r) => (
              <tr key={r.hashLinha} className="border-b border-line last:border-0">
                {colunas.map((c, i) => (
                  <td key={c} className={`p-3 ${['peso_kg', 'arrobas', 'quantidade', 'minimo', 'custo_unitario'].includes(c) ? 'num text-right' : ''} ${i === 0 ? 'sticky left-0 bg-panel' : ''}`}>
                    {valor(c, r.campos[c])}
                  </td>
                ))}
                <td className="p-3 text-right">
                  <button onClick={() => setOrigem({ arquivoId: r.arquivoId, linha: r.origem.linha })}
                    className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent whitespace-nowrap">origem</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {regs.length === 0 && <div className="p-5"><Vazio>Nenhum registro nesta área ainda.</Vazio></div>}
      </Cartao>
      {origem && <LinhaOrigem estado={estado} arquivoId={origem.arquivoId} linha={origem.linha} fechar={() => setOrigem(null)} />}
    </div>
  )
}
