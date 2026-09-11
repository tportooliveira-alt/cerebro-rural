import { describe, expect, it } from 'vitest'
import { detectar, detectarEncoding, detectarSeparador } from '../detectar'

const b = (s: string, enc: 'utf8' | 'latin1' = 'utf8') => new Uint8Array(Buffer.from(s, enc))

describe('detectar', () => {
  it('xlsx pelo magic PK', () => expect(detectar(new Uint8Array([0x50, 0x4b, 0x03, 0x04, 0, 0])).formato).toBe('xlsx'))
  it('xls pelo magic OLE', () => expect(detectar(new Uint8Array([0xd0, 0xcf, 0x11, 0xe0, 0, 0])).formato).toBe('xls'))
  it('pdf', () => expect(detectar(b('%PDF-1.4 ...')).formato).toBe('pdf'))
  it('ofx v1 e v2', () => {
    expect(detectar(b('OFXHEADER:100\nDATA:OFXSGML\n<OFX>')).formato).toBe('ofx')
    expect(detectar(b('<?xml version="1.0"?><OFX><SIGNONMSGSRSV1/></OFX>')).formato).toBe('ofx')
  })
  it('nfe xml', () => expect(detectar(b('<?xml version="1.0"?><nfeProc><NFe></NFe></nfeProc>')).formato).toBe('nfe_xml'))
  it('csv ; latin1', () => {
    const d = detectar(b('Data;Histórico;Valor\n01/08/2026;Pix João;-1.850,00\n', 'latin1'), 'extrato.csv')
    expect(d).toMatchObject({ formato: 'csv', encoding: 'latin1', separador: ';' })
  })
  it('csv , utf8 com BOM', () => {
    const d = detectar(b('﻿id,data,valor\n1,2026-08-01,10.50\n'))
    expect(d).toMatchObject({ formato: 'csv', encoding: 'utf-8', bom: true, separador: ',' })
  })
  it('tsv', () => expect(detectar(b('a\tb\tc\n1\t2\t3\n')).formato).toBe('tsv'))
  it('encoding', () => {
    expect(detectarEncoding(b('café')).encoding).toBe('utf-8')
    expect(detectarEncoding(b('café', 'latin1')).encoding).toBe('latin1')
  })
  it('separador: vírgula dentro de aspas não conta', () => {
    expect(detectarSeparador('a;b;c\n"1,5";x;y\n"2,5";z;w')).toBe(';')
    expect(detectarSeparador('a,b,c\n1.5,x,y\n2.5,z,w')).toBe(',')
  })
})
