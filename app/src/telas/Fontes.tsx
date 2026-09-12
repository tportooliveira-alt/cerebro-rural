import type { Estado, Fonte } from '../estado/store'
import { Cartao, Rotulo, Selo, Vazio } from '../componentes'
import { dataBR } from '../formato'
import { NOME_AREA } from './Hoje'

type Estágio = 'ok' | 'silenciosa' | 'com_erro' | 'nunca_leu'

export function estadoDaFonte(f: Fonte, estado: Estado): Estágio {
  if (!f.ultimaLeitura) return 'nunca_leu'
  const ultimo = estado.arquivos.find((a) => a.fonteId === f.id)
  if (ultimo && ultimo.rejeitadas > 0) return 'com_erro'
  return Date.now() - new Date(f.ultimaLeitura).getTime() > 7 * 864e5 ? 'silenciosa' : 'ok'
}

const SELO: Record<Estágio, { cor: 'ok' | 'warn' | 'bad' | 'neutro'; texto: string }> = {
  ok: { cor: 'ok', texto: 'ok' },
  silenciosa: { cor: 'warn', texto: 'silenciosa' },
  com_erro: { cor: 'bad', texto: 'com erro' },
  nunca_leu: { cor: 'neutro', texto: 'nunca leu' },
}

const CANAL: Record<string, string> = { sheets: 'Google Sheets', upload: 'Upload', email: 'E-mail', drive: 'Drive', http: 'HTTP', whatsapp: 'WhatsApp' }

export function TelaFontes({ estado }: { estado: Estado }) {
  if (estado.fontes.length === 0) return <Vazio>Nenhuma fonte plugada. Solte um arquivo para começar.</Vazio>
  return (
    <div className="grid gap-4">
      <div className="grid sm:grid-cols-2 gap-4">
        {estado.fontes.map((f) => {
          const est = estadoDaFonte(f, estado)
          const arquivos = estado.arquivos.filter((a) => a.fonteId === f.id)
          const rejeitadas = estado.rejeitados.filter((r) => r.fonteId === f.id).length
          return (
            <Cartao key={f.id} className="p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-base">{f.nome}</h3>
                  <Rotulo>{NOME_AREA[f.area]} · {CANAL[f.canal] ?? f.canal}</Rotulo>
                </div>
                <div className="flex flex-col items-end gap-1">
                  <Selo cor={SELO[est].cor}>{SELO[est].texto}</Selo>
                  {f.exemplo && <Selo>exemplo</Selo>}
                </div>
              </div>
              <ul className="list-none p-0 m-0 mt-3 grid gap-1 text-[.9rem] text-ink2">
                <li>{arquivos.length} arquivo{arquivos.length !== 1 ? 's' : ''} lido{arquivos.length !== 1 ? 's' : ''}
                  {f.ultimaLeitura && <> · último em {dataBR(f.ultimaLeitura.slice(0, 10))}</>}</li>
                <li className="num">
                  {arquivos.reduce((s, a) => s + a.novas, 0)} linhas gravadas
                  {arquivos.reduce((s, a) => s + a.duplicadas, 0) > 0 && <> · {arquivos.reduce((s, a) => s + a.duplicadas, 0)} duplicadas barradas</>}
                </li>
                {rejeitadas > 0 && <li className="text-bad">{rejeitadas} linha{rejeitadas > 1 ? 's' : ''} não entrou: falta campo obrigatório</li>}
              </ul>
            </Cartao>
          )
        })}
      </div>

      {estado.rejeitados.length > 0 && (
        <Cartao className="p-5">
          <h3 className="text-base">Revisão — o que não entrou, e por quê</h3>
          <p className="text-ink2 text-[.9rem] mt-1 mb-3">Nada foi descartado em silêncio. Cada linha abaixo ficou de fora com motivo.</p>
          <ul className="list-none p-0 m-0 grid gap-2">
            {estado.rejeitados.slice(0, 20).map((r, i) => (
              <li key={i} className="flex gap-3 items-baseline flex-wrap border-b border-line pb-2 last:border-0">
                <span className="rotulo whitespace-nowrap">{estado.fontes.find((f) => f.id === r.fonteId)?.nome} · {r.aba} L{r.linha}</span>
                <span className="text-[.92rem]">{r.mensagem}</span>
                <Selo cor="bad">{r.codigo}</Selo>
              </li>
            ))}
          </ul>
        </Cartao>
      )}
    </div>
  )
}
