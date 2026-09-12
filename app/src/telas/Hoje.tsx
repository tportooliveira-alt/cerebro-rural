import { useMemo } from 'react'
import type { Estado } from '../estado/store'
import { Barras, Cartao, Rotulo, Selo, Vazio } from '../componentes'
import { brl, brlCurto, dataBR, num } from '../formato'
import type { Area } from '../tomada'

const NOME_AREA: Record<Area, string> = {
  financas: 'Finanças', gado: 'Gado', estoque: 'Estoque',
  almoxarifado: 'Almoxarifado', ferramentas: 'Ferramentas', pasto: 'Pasto',
}

export function Hoje({ estado, mes, irPara }: { estado: Estado; mes: string; irPara: (a: Area | 'fontes') => void }) {
  const fin = useMemo(() => {
    const doMes = estado.lancamentos.filter((l) => l.data.startsWith(mes) && !l.neutro)
    const entradas = doMes.filter((l) => l.tipo === 'ENTRADA').reduce((s, l) => s + l.valor, 0)
    const saidas = doMes.filter((l) => l.tipo === 'SAIDA').reduce((s, l) => s + l.valor, 0)
    const porCategoria = new Map<string, number>()
    for (const l of doMes.filter((l) => l.tipo === 'SAIDA')) {
      const k = l.categoria || 'Sem categoria'
      porCategoria.set(k, (porCategoria.get(k) ?? 0) + l.valor)
    }
    const neutros = estado.lancamentos.filter((l) => l.data.startsWith(mes) && l.neutro)
    return { entradas, saidas, resultado: entradas - saidas, lancamentos: doMes.length, neutros: neutros.length,
      categorias: [...porCategoria].sort((a, b) => b[1] - a[1]).map(([nome, valor]) => ({ nome, valor, sub: brl(valor) })) }
  }, [estado.lancamentos, mes])

  const porArea = useMemo(() => {
    const m = new Map<Area, number>()
    for (const r of estado.registros) m.set(r.area, (m.get(r.area) ?? 0) + 1)
    return m
  }, [estado.registros])

  const gado = useMemo(() => {
    const regs = estado.registros.filter((r) => r.area === 'gado')
    const brincos = new Set(regs.map((r) => String(r.campos.brinco ?? '')).filter(Boolean))
    const pesagens = regs.filter((r) => r.campos.evento === 'pesagem')
    const semPasto = regs.filter((r) => !r.campos.pasto)
    const pesos = pesagens.map((r) => Number(r.campos.peso_kg)).filter((n) => Number.isFinite(n) && n > 0)
    return { cabecas: brincos.size || regs.length, pesagens: pesagens.length, semPasto: semPasto.length,
      pesoMedio: pesos.length ? pesos.reduce((a, b) => a + b, 0) / pesos.length : 0 }
  }, [estado.registros])

  const saldos = useMemo(() => {
    const calc = (area: Area) => {
      const m = new Map<string, { saldo: number; unidade: string; minimo: number }>()
      for (const r of estado.registros.filter((x) => x.area === area)) {
        const item = String(r.campos.item ?? '')
        if (!item) continue
        const q = Number(r.campos.quantidade) || 0
        const at = m.get(item) ?? { saldo: 0, unidade: String(r.campos.unidade ?? ''), minimo: Number(r.campos.minimo) || 0 }
        const t = r.campos.tipo_mov
        at.saldo += t === 'saida' ? -q : t === 'saldo' || t === 'entrada' || t === 'ajuste' ? q : 0
        if (!at.minimo && r.campos.minimo) at.minimo = Number(r.campos.minimo)
        m.set(item, at)
      }
      const itens = [...m].map(([nome, v]) => ({ nome, ...v }))
      return { itens, abaixo: itens.filter((i) => i.minimo > 0 && i.saldo < i.minimo) }
    }
    return { estoque: calc('estoque'), almoxarifado: calc('almoxarifado') }
  }, [estado.registros])

  const ferramentas = useMemo(() => {
    const regs = estado.registros.filter((r) => r.area === 'ferramentas')
    return { total: regs.length, manutencao: regs.filter((r) => /manuten|quebr|perdid/i.test(String(r.campos.estado ?? ''))).length,
      responsaveis: new Set(regs.map((r) => String(r.campos.responsavel ?? '')).filter((x) => x && !/ningu/i.test(x))).size }
  }, [estado.registros])

  const fontesSilenciosas = estado.fontes.filter((f) => {
    if (!f.ultimaLeitura) return true
    return Date.now() - new Date(f.ultimaLeitura).getTime() > 7 * 864e5
  })

  return (
    <div className="grid gap-5">
      {/* Finanças — o bloco principal */}
      <Cartao className="p-5">
        <div className="flex items-baseline justify-between gap-3 flex-wrap">
          <h2 className="text-xl">Finanças</h2>
          <button onClick={() => irPara('financas')} className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent">ver tudo →</button>
        </div>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-px bg-line border border-line mt-4">
          {[
            { r: 'entrou', v: brlCurto(fin.entradas), c: 'text-ok' },
            { r: 'saiu', v: brlCurto(fin.saidas), c: 'text-bad' },
            { r: 'resultado', v: brlCurto(fin.resultado), c: fin.resultado >= 0 ? 'text-ink' : 'text-bad' },
          ].map((k) => (
            <div key={k.r} className="bg-panel p-4">
              <div className={`font-display font-extrabold text-2xl leading-tight num ${k.c}`}>{k.v}</div>
              <Rotulo>{k.r}</Rotulo>
            </div>
          ))}
        </div>
        {fin.categorias.length > 0 ? (
          <div className="mt-5">
            <Rotulo>saídas por categoria</Rotulo>
            <div className="mt-3"><Barras itens={fin.categorias} cor="bad" /></div>
          </div>
        ) : <p className="text-ink2 mt-4 mb-0 text-[.95rem]">Nenhum lançamento neste mês.</p>}
        <p className="text-ink2 text-[.88rem] mt-4 mb-0">
          {fin.lancamentos} lançamentos{fin.neutros > 0 && <> · {fin.neutros} transferência{fin.neutros > 1 ? 's' : ''} fora do resultado</>}
        </p>
      </Cartao>

      {/* Um cartão por app plugado */}
      <div className="grid sm:grid-cols-2 gap-5">
        {porArea.has('gado') && (
          <Cartao className="p-5">
            <div className="flex items-baseline justify-between gap-3">
              <h2 className="text-lg">Gado</h2>
              <button onClick={() => irPara('gado')} className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent">abrir →</button>
            </div>
            <p className="font-display font-extrabold text-2xl mt-3 mb-0 num">{gado.cabecas} <span className="text-base font-normal text-ink2">cabeças</span></p>
            <ul className="list-none p-0 mt-3 mb-0 grid gap-1 text-[.92rem] text-ink2">
              <li>{gado.pesagens} pesagens lidas{gado.pesoMedio > 0 && <> · média {num(gado.pesoMedio, 1)} kg</>}</li>
              {gado.semPasto > 0 && <li className="flex items-center gap-2"><Selo cor="warn">{gado.semPasto} sem pasto</Selo> atribuir no painel</li>}
            </ul>
          </Cartao>
        )}

        {(['estoque', 'almoxarifado'] as const).filter((a) => porArea.has(a)).map((area) => {
          const s = saldos[area]
          return (
            <Cartao key={area} className="p-5">
              <div className="flex items-baseline justify-between gap-3">
                <h2 className="text-lg">{NOME_AREA[area]}</h2>
                <button onClick={() => irPara(area)} className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent">abrir →</button>
              </div>
              <p className="font-display font-extrabold text-2xl mt-3 mb-0 num">{s.itens.length} <span className="text-base font-normal text-ink2">itens</span></p>
              {s.abaixo.length > 0 ? (
                <ul className="list-none p-0 mt-3 mb-0 grid gap-2 text-[.92rem]">
                  {s.abaixo.slice(0, 3).map((i) => (
                    <li key={i.nome} className="flex items-center gap-2 flex-wrap">
                      <Selo cor="bad">abaixo do mínimo</Selo>
                      <span>{i.nome}</span>
                      <span className="num text-ink2">{num(i.saldo, 0)} / {num(i.minimo, 0)} {i.unidade}</span>
                    </li>
                  ))}
                </ul>
              ) : <p className="text-ink2 text-[.92rem] mt-3 mb-0">Nenhum item abaixo do mínimo.</p>}
            </Cartao>
          )
        })}

        {porArea.has('ferramentas') && (
          <Cartao className="p-5">
            <div className="flex items-baseline justify-between gap-3">
              <h2 className="text-lg">Ferramentas</h2>
              <button onClick={() => irPara('ferramentas')} className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent">abrir →</button>
            </div>
            <p className="font-display font-extrabold text-2xl mt-3 mb-0 num">{ferramentas.total} <span className="text-base font-normal text-ink2">ferramentas</span></p>
            <ul className="list-none p-0 mt-3 mb-0 grid gap-1 text-[.92rem] text-ink2">
              <li>{ferramentas.responsaveis} pessoas com ferramenta na mão</li>
              {ferramentas.manutencao > 0 && <li className="flex items-center gap-2"><Selo cor="warn">{ferramentas.manutencao} em manutenção</Selo></li>}
            </ul>
          </Cartao>
        )}
      </div>

      {/* Estado das fontes */}
      <Cartao className="p-5">
        <div className="flex items-baseline justify-between gap-3">
          <h2 className="text-lg">Fontes plugadas</h2>
          <button onClick={() => irPara('fontes')} className="rotulo cursor-pointer bg-transparent border-0 p-0 text-accent">ver todas →</button>
        </div>
        {estado.fontes.length === 0 ? <Vazio>Nenhuma fonte ainda. Solte um arquivo para plugar a primeira.</Vazio> : (
          <p className="text-ink2 text-[.92rem] mt-3 mb-0">
            {estado.fontes.length} fontes · {estado.arquivos.length} arquivos lidos
            {fontesSilenciosas.length > 0 && <> · <span className="text-warn">{fontesSilenciosas.length} silenciosa{fontesSilenciosas.length > 1 ? 's' : ''}</span></>}
            {estado.rejeitados.length > 0 && <> · <span className="text-bad">{estado.rejeitados.length} linha{estado.rejeitados.length > 1 ? 's' : ''} em revisão</span></>}
          </p>
        )}
        <p className="text-ink2 text-[.88rem] mt-3 mb-0">Última leitura: {estado.arquivos[0] ? dataBR(estado.arquivos[0].lidoEm.slice(0, 10)) : '—'}</p>
      </Cartao>
    </div>
  )
}

export { NOME_AREA }
