// Empacota as fixtures como base64 para o Painel abrir já com dados reais passados
// pela Tomada de verdade (mesmos bytes, mesmo pipeline) — não com números inventados.
import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from 'node:fs'
import { join } from 'node:path'

const FONTES = [
  { arquivo: 'extrato-bb.csv',            slug: 'banco-bb',           nome: 'Extrato Banco do Brasil', area: 'financas',     canal: 'email'  },
  { arquivo: 'extrato-sicoob.csv',        slug: 'banco-sicoob',       nome: 'Extrato Sicoob',          area: 'financas',     canal: 'email'  },
  { arquivo: 'caderno-fazenda.xlsx',      slug: 'caderno-fazenda',    nome: 'Caderno da fazenda',      area: 'financas',     canal: 'sheets' },
  { arquivo: 'frigogest-vendas.csv',      slug: 'frigogest',          nome: 'FrigoGest',               area: 'financas',     canal: 'http'   },
  { arquivo: 'gado/rebanho.xlsx',         slug: 'planilha-rebanho',   nome: 'Planilha de rebanho',     area: 'gado',         canal: 'sheets' },
  { arquivo: 'gado/calculadora-boi.csv',  slug: 'calculadora-boi',    nome: 'Calculadora de Boi',      area: 'gado',         canal: 'http'   },
  { arquivo: 'estoque/movimentos.csv',    slug: 'planilha-estoque',   nome: 'Planilha de estoque',     area: 'estoque',      canal: 'sheets' },
  { arquivo: 'ferramentas/inventario.csv',slug: 'planilha-ferramentas',nome: 'Inventário de ferramentas', area: 'ferramentas', canal: 'sheets' },
]

mkdirSync('src/seed', { recursive: true })
const linhas = FONTES.map((f) => {
  const b64 = readFileSync(join('fixtures', f.arquivo)).toString('base64')
  return `  { slug: ${JSON.stringify(f.slug)}, nome: ${JSON.stringify(f.nome)}, area: ${JSON.stringify(f.area)}, canal: ${JSON.stringify(f.canal)}, arquivo: ${JSON.stringify(f.arquivo.split('/').pop())}, b64: ${JSON.stringify(b64)} },`
})
writeFileSync('src/seed/arquivos.ts', `// GERADO por scripts/gerar-seed.mjs — não editar à mão.
// Fixtures de exemplo, marcadas como exemplo no Painel. Rode 'npm run seed' depois de trocar uma fixture.
import type { Area } from '../tomada/areas'

export interface FonteSeed { slug: string; nome: string; area: Area; canal: string; arquivo: string; b64: string }

export const SEED: FonteSeed[] = [
${linhas.join('\n')}
]
`)
console.log('seed gerado com', FONTES.length, 'fontes')
