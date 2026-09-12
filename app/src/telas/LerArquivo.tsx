import { useState, type DragEvent } from 'react'
import { AREAS, type Area } from '../tomada'
import { preparar, type Estado, type Previa } from '../estado/store'
import { Botao, Rotulo, Selo, Vazio } from '../componentes'
import { brl, celula, dataBR } from '../formato'
import { NOME_AREA } from './Hoje'

export function LerArquivo({ estado, fechar, confirmar }: { estado: Estado; fechar: () => void; confirmar: (p: Previa) => void }) {
  const [area, setArea] = useState<Area>('financas')
  const [nomeFonte, setNomeFonte] = useState('')
  const [previa, setPrevia] = useState<Previa | null>(null)
  const [erro, setErro] = useState('')
  const [lendo, setLendo] = useState(false)
  const [sobre, setSobre] = useState(false)

  async function receber(file: File) {
    setErro(''); setLendo(true)
    try {
      const bytes = new Uint8Array(await file.arrayBuffer())
      const slug = (nomeFonte || file.name.replace(/\.[^.]+$/, '')).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40) || 'fonte'
      const existente = estado.fontes.find((f) => f.slug === slug)
      const fonte = existente ?? { id: crypto.randomUUID(), slug, nome: nomeFonte || file.name, area, canal: 'upload', arquivos: 0 }
      setPrevia(await preparar(estado, fonte, file.name, bytes))
    } catch (e) {
      setErro(e instanceof Error ? e.message : 'Não consegui ler este arquivo.')
    } finally { setLendo(false) }
  }

  const novas = previa?.marcas.filter((m) => m === 'nova').length ?? 0
  const dup = previa?.marcas.filter((m) => m === 'duplicada').length ?? 0
  const prov = previa?.marcas.filter((m) => m === 'provavel').length ?? 0

  return (
    <div className="fixed inset-0 z-30 bg-black/50 flex items-end sm:items-center justify-center sm:p-5" onClick={fechar}>
      <div className="bg-panel border border-line rounded-t-lg sm:rounded-sm w-full max-w-3xl max-h-[90vh] overflow-auto" onClick={(e) => e.stopPropagation()}>
        <div className="p-5 border-b border-line sticky top-0 bg-panel flex items-center justify-between gap-3">
          <div>
            <Rotulo>tomada</Rotulo>
            <h2 className="text-xl mt-1">{previa ? 'Confira antes de gravar' : 'Plugar um arquivo'}</h2>
          </div>
          <Botao variante="discreto" onClick={fechar}>fechar</Botao>
        </div>

        {!previa ? (
          <div className="p-5 grid gap-4">
            <div className="grid sm:grid-cols-2 gap-4">
              <label className="grid gap-1">
                <Rotulo>área</Rotulo>
                <select id="area" value={area} onChange={(e) => setArea(e.target.value as Area)}
                  className="bg-bg border border-line rounded-sm px-3 py-2 text-ink text-[.95rem]">
                  {AREAS.map((a) => <option key={a} value={a}>{NOME_AREA[a]}</option>)}
                </select>
              </label>
              <label className="grid gap-1">
                <Rotulo>nome da fonte (opcional)</Rotulo>
                <input id="nomeFonte" value={nomeFonte} onChange={(e) => setNomeFonte(e.target.value)} placeholder="Ex.: Extrato Banco do Brasil"
                  className="bg-bg border border-line rounded-sm px-3 py-2 text-ink text-[.95rem]" />
              </label>
            </div>

            <div
              onDragOver={(e: DragEvent) => { e.preventDefault(); setSobre(true) }}
              onDragLeave={() => setSobre(false)}
              onDrop={(e: DragEvent) => { e.preventDefault(); setSobre(false); const f = e.dataTransfer.files[0]; if (f) void receber(f) }}
              className={`border border-dashed rounded-sm p-8 text-center ${sobre ? 'border-accent bg-accentsoft' : 'border-line'}`}
            >
              <p className="m-0 text-[.95rem]">Solte aqui a planilha, o extrato ou o export.</p>
              <p className="text-ink2 text-[.88rem] mt-1 mb-4">xlsx · csv · ofx · xml de NF-e — a leitura acontece no seu aparelho.</p>
              <label className="inline-block">
                <input id="arquivo" type="file" accept=".xlsx,.xls,.csv,.tsv,.ofx,.xml,.txt" className="sr-only"
                  onChange={(e) => { const f = e.target.files?.[0]; if (f) void receber(f) }} />
                <span className="font-mono text-[.72rem] uppercase tracking-wider px-3 py-2 rounded-sm cursor-pointer bg-accent text-bg inline-block">escolher arquivo</span>
              </label>
            </div>
            {lendo && <p className="text-ink2 m-0">Lendo…</p>}
            {erro && <p className="text-bad m-0 text-[.95rem]">{erro}</p>}
          </div>
        ) : (
          <div className="p-5 grid gap-5">
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-px bg-line border border-line">
              {[
                { r: 'formato', v: previa.fonte.area === 'financas' ? previa.nome.split('.').pop()?.toUpperCase() ?? '?' : previa.nome.split('.').pop()?.toUpperCase() ?? '?' },
                { r: 'novas', v: String(novas) },
                { r: 'duplicadas', v: String(dup) },
                { r: 'não entraram', v: String(previa.rejeitados.length) },
              ].map((k) => (
                <div key={k.r} className="bg-panel p-3">
                  <div className="font-display font-extrabold text-xl num">{k.v}</div>
                  <Rotulo>{k.r}</Rotulo>
                </div>
              ))}
            </div>

            {previa.jaLido && <p className="m-0"><Selo cor="warn">arquivo já lido</Selo> <span className="text-ink2 text-[.92rem]">Este arquivo exato já entrou antes. Gravar de novo não duplica nada.</span></p>}
            {prov > 0 && <p className="m-0"><Selo cor="warn">{prov} provável duplicata</Selo> <span className="text-ink2 text-[.92rem]">Mesmo valor e data em outra fonte — vai gravar e ficar marcado para você decidir.</span></p>}

            <div>
              <Rotulo>como eu li cada coluna</Rotulo>
              <ul className="list-none p-0 m-0 mt-2 flex flex-wrap gap-2">
                {Object.entries(previa.mapa).map(([cab, campo]) => (
                  <li key={cab} className="border border-line rounded-sm px-2 py-1 text-[.85rem]">
                    <span className="text-ink2">{cab}</span> <span className="text-accent">→</span> <span className="font-mono text-[.78rem]">{campo}</span>
                  </li>
                ))}
              </ul>
            </div>

            {previa.ignoradas.length > 0 && (
              <div>
                <Rotulo>linhas que eu ignorei, e por quê</Rotulo>
                <ul className="list-none p-0 m-0 mt-2 grid gap-1 text-[.9rem] text-ink2">
                  {previa.ignoradas.map((i) => <li key={i.n}>linha {i.n} — {i.motivo}</li>)}
                </ul>
              </div>
            )}

            {previa.rejeitados.length > 0 && (
              <div>
                <Rotulo>não entraram</Rotulo>
                <ul className="list-none p-0 m-0 mt-2 grid gap-1 text-[.9rem]">
                  {previa.rejeitados.map((r, i) => <li key={i}><span className="text-bad">linha {r.linha}</span> <span className="text-ink2">— {r.mensagem}</span></li>)}
                </ul>
              </div>
            )}

            <div>
              <Rotulo>o que vai entrar</Rotulo>
              <div className="overflow-x-auto mt-2 border border-line rounded-sm">
                <table className="w-full border-collapse text-[.88rem] min-w-[520px]">
                  <tbody>
                    {previa.fonte.area === 'financas'
                      ? previa.lancamentos.slice(0, 12).map((l, i) => (
                        <tr key={l.hashLinha} className="border-b border-line last:border-0">
                          <td className="p-2"><Selo cor={previa.marcas[i] === 'nova' ? 'ok' : previa.marcas[i] === 'duplicada' ? 'neutro' : 'warn'}>{previa.marcas[i]}</Selo></td>
                          <td className="p-2 num whitespace-nowrap">{dataBR(l.data)}</td>
                          <td className="p-2">{l.descricao}</td>
                          <td className={`p-2 num text-right whitespace-nowrap ${l.tipo === 'ENTRADA' ? 'text-ok' : 'text-bad'}`}>{l.tipo === 'ENTRADA' ? '' : '−'}{brl(l.valor)}</td>
                        </tr>
                      ))
                      : previa.registros.slice(0, 12).map((r, i) => (
                        <tr key={r.hashLinha} className="border-b border-line last:border-0">
                          <td className="p-2"><Selo cor={previa.marcas[i] === 'nova' ? 'ok' : 'neutro'}>{previa.marcas[i]}</Selo></td>
                          {Object.entries(r.campos).filter(([, v]) => v !== null).slice(0, 5).map(([k, v]) => (
                            <td key={k} className="p-2">{celula(v)}</td>
                          ))}
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
              {(previa.lancamentos.length + previa.registros.length) > 12 && (
                <p className="text-ink2 text-[.85rem] mt-2 mb-0">mostrando 12 de {previa.lancamentos.length + previa.registros.length}</p>
              )}
              {previa.lancamentos.length + previa.registros.length === 0 && <div className="p-4"><Vazio>Nada legível neste arquivo. Veja acima o motivo de cada linha.</Vazio></div>}
            </div>

            <div className="flex gap-3 flex-wrap sticky bottom-0 bg-panel pt-3 border-t border-line">
              <Botao variante="primario" disabled={novas === 0} onClick={() => confirmar(previa)}>
                {novas > 0 ? `gravar ${novas} linha${novas > 1 ? 's' : ''}` : 'nada novo para gravar'}
              </Botao>
              <Botao onClick={() => setPrevia(null)}>escolher outro</Botao>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
