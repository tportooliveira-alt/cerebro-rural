import { chromium } from 'playwright'
const D = '/tmp/claude-0/-home-user-cerebro-rural/fbfaf838-4875-5220-a37a-9291f58bce40/scratchpad'
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' })
const erros = []
for (const [nome, w, h, tema] of [['desktop', 1100, 1400, 'light'], ['celular', 390, 1500, 'dark']]) {
  const p = await b.newPage({ viewport: { width: w, height: h }, colorScheme: tema, deviceScaleFactor: 1 })
  p.on('console', (m) => m.type() === 'error' && erros.push(nome + ': ' + m.text()))
  p.on('pageerror', (e) => erros.push(nome + ' pageerror: ' + e.message))
  await p.goto('http://localhost:8899/', { waitUntil: 'networkidle' })
  await p.waitForSelector('h2', { timeout: 15000 })
  await p.screenshot({ path: `${D}/painel-${nome}.png`, fullPage: true })
  if (nome === 'desktop') {
    // abre a aba Gado e a origem de uma linha
    await p.getByRole('button', { name: 'Gado', exact: true }).click()
    await p.waitForTimeout(300)
    await p.screenshot({ path: `${D}/painel-gado.png`, fullPage: true })
    await p.getByRole('button', { name: 'origem' }).first().click()
    await p.waitForTimeout(300)
    await p.screenshot({ path: `${D}/painel-origem.png` })
  }
  await p.close()
}
await b.close()
console.log(erros.length ? 'ERROS:\n' + erros.join('\n') : 'sem erros de console')
