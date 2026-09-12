import { useEffect, useMemo, useState } from 'react'
import { AREAS, type Area } from './tomada'
import { carregar, gravar, limpar, salvar, semear, vazio, type Estado, type Previa } from './estado/store'
import { Botao, Rotulo } from './componentes'
import { mesNome } from './formato'
import { Hoje, NOME_AREA } from './telas/Hoje'
import { TelaArea, TelaFinancas } from './telas/Area'
import { TelaFontes } from './telas/Fontes'
import { LerArquivo } from './telas/LerArquivo'

type Aba = 'hoje' | Area | 'fontes'

export default function App() {
  const [estado, setEstado] = useState<Estado | null>(null)
  const [aba, setAba] = useState<Aba>('hoje')
  const [mes, setMes] = useState('2026-08')
  const [lendo, setLendo] = useState(false)

  useEffect(() => {
    const salvo = carregar()
    if (salvo) { setEstado(salvo); return }
    void semear().then((e) => { setEstado(e); salvar(e) }).catch(() => setEstado(vazio()))
  }, [])

  const meses = useMemo(() => {
    if (!estado) return []
    const s = new Set(estado.lancamentos.map((l) => l.data.slice(0, 7)))
    for (const r of estado.registros) if (typeof r.campos.data === 'string' && r.campos.data) s.add(r.campos.data.slice(0, 7))
    return [...s].sort().reverse()
  }, [estado])

  useEffect(() => { if (meses.length && !meses.includes(mes)) setMes(meses[0]) }, [meses, mes])

  const areasComDados = useMemo(() => {
    if (!estado) return [] as Area[]
    const s = new Set<Area>()
    if (estado.lancamentos.length) s.add('financas')
    for (const r of estado.registros) s.add(r.area)
    return AREAS.filter((a) => s.has(a))
  }, [estado])

  function confirmar(p: Previa) {
    if (!estado) return
    const comFonte: Estado = estado.fontes.some((f) => f.slug === p.fonte.slug)
      ? estado : { ...estado, fontes: [...estado.fontes, { ...p.fonte, arquivos: 0 }] }
    const novo = gravar(comFonte, p)
    setEstado(novo); salvar(novo); setLendo(false)
  }

  if (!estado) return (
    <main className="mx-auto max-w-5xl px-5 py-16"><p className="rotulo">Lendo as fontes de exemplo…</p></main>
  )

  const temExemplo = estado.fontes.some((f) => f.exemplo)

  return (
    <>
      <header className="sticky top-0 z-20 bg-bg border-b border-line">
        <div className="mx-auto max-w-5xl px-5">
          <div className="flex items-center gap-4 flex-wrap py-3">
            <div className="mr-auto">
              <h1 className="font-display font-extrabold text-base leading-tight">Cérebro Rural</h1>
              <Rotulo>Fazenda Boa Vista · {mesNome(mes)}</Rotulo>
            </div>
            {meses.length > 0 && (
              <label className="flex items-center gap-2">
                <span className="sr-only">mês</span>
                <select id="mes" value={mes} onChange={(e) => setMes(e.target.value)}
                  className="bg-panel border border-line rounded-sm px-2 py-2 text-ink font-mono text-[.78rem] min-h-[44px] sm:min-h-0">
                  {meses.map((m) => <option key={m} value={m}>{m}</option>)}
                </select>
              </label>
            )}
            <Botao variante="primario" onClick={() => setLendo(true)}>plugar arquivo</Botao>
          </div>
          <nav className="flex gap-1 overflow-x-auto pb-2" aria-label="áreas">
            {(['hoje', ...areasComDados, 'fontes'] as Aba[]).map((a) => (
              <button key={a} onClick={() => setAba(a)} aria-current={aba === a}
                className={`font-mono text-[.72rem] uppercase tracking-wider px-3 py-2 rounded-sm cursor-pointer whitespace-nowrap border ${
                  aba === a ? 'bg-panel text-accent border-line' : 'bg-transparent text-ink2 border-transparent'}`}>
                {a === 'hoje' ? 'Hoje' : a === 'fontes' ? 'Fontes' : NOME_AREA[a as Area]}
              </button>
            ))}
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-5 py-6">
        {temExemplo && aba === 'hoje' && (
          <p className="text-[.88rem] text-ink2 bg-panel2 border border-line rounded-sm px-4 py-3 mt-0 mb-5">
            Os números abaixo vieram de <strong>arquivos de exemplo</strong> lidos pela Tomada de verdade — extrato de banco, caderno da fazenda,
            export da Calculadora de Boi, planilha de estoque e de ferramentas. Solte um arquivo seu para ver os seus.
            <button onClick={() => { limpar(); location.reload() }} className="rotulo text-accent bg-transparent border-0 p-0 ml-2 cursor-pointer">limpar exemplos</button>
          </p>
        )}

        {aba === 'hoje' && <Hoje estado={estado} mes={mes} irPara={(a) => setAba(a)} />}
        {aba === 'financas' && <TelaFinancas estado={estado} mes={mes} />}
        {aba !== 'hoje' && aba !== 'fontes' && aba !== 'financas' && <TelaArea estado={estado} area={aba as Exclude<Area, 'financas'>} />}
        {aba === 'fontes' && <TelaFontes estado={estado} />}
      </main>

      <footer className="mx-auto max-w-5xl px-5 pb-10">
        <p className="text-ink2 text-[.82rem] m-0">
          Protótipo do Painel. Tudo fica no seu navegador — nenhum dado sai do aparelho. Banco e login entram na próxima fase.
        </p>
      </footer>

      {lendo && <LerArquivo estado={estado} fechar={() => setLendo(false)} confirmar={confirmar} />}
    </>
  )
}
