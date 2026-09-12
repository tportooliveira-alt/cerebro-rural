export const brl = (n: number) => n.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
export const brlCurto = (n: number) =>
  Math.abs(n) >= 1000 ? 'R$ ' + (n / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + ' mil' : brl(n)
export const num = (n: number, casas = 0) => n.toLocaleString('pt-BR', { minimumFractionDigits: casas, maximumFractionDigits: casas })
export const dataBR = (iso: string) => (iso ? iso.slice(8, 10) + '/' + iso.slice(5, 7) + '/' + iso.slice(0, 4) : '—')
export const mesNome = (mes: string) => {
  const [a, m] = mes.split('-')
  return ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'][Number(m) - 1] + ' de ' + a
}
export const celula = (c: unknown): string => {
  if (c === null || c === undefined) return ''
  if (c instanceof Date) return c.toLocaleDateString('pt-BR')
  return String(c)
}
