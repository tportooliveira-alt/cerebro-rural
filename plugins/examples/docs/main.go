// docs — adaptador universal de leitura. Detecta o formato (xlsx, xls, csv, tsv,
// pdf, json, xml, txt, md) por extensão + magic bytes e devolve conteúdo em JSON.
package main

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/ledongthuc/pdf"
	"github.com/xuri/excelize/v2"

	extv1 "github.com/tportooliveira-alt/cerebro-rural/plugins/proto/extension/v1"
	sdk "github.com/tportooliveira-alt/cerebro-rural/plugins/sdk/go"
)

const (
	moduleName = "docs"
	maxBytes   = 64 * 1024 * 1024 // 64 MiB
)

type docs struct{}

func (docs) PluginID() string      { return "docs" }
func (docs) PluginVersion() string { return "0.1.0" }

func (docs) Capabilities(_ context.Context) ([]*extv1.Capability, error) {
	pathOnly := `{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}`
	cells := `{"type":"object","properties":{"path":{"type":"string"},"sheet":{"type":"string"},"range":{"type":"string"}},"required":["path"]}`
	return []*extv1.Capability{
		{Module: moduleName, Action: "detect", SchemaPayload: pathOnly},
		{Module: moduleName, Action: "read", SchemaPayload: pathOnly},
		{Module: moduleName, Action: "text", SchemaPayload: pathOnly},
		{Module: moduleName, Action: "sheets", SchemaPayload: pathOnly},
		{Module: moduleName, Action: "cells", SchemaPayload: cells},
	}, nil
}

type basePayload struct {
	Path string `json:"path"`
}

type cellsPayload struct {
	Path  string `json:"path"`
	Sheet string `json:"sheet"`
	Range string `json:"range"`
}

func (docs) Validate(_ context.Context, cmd *extv1.Command) (*extv1.ValidateResponse, error) {
	if cmd.Module != moduleName {
		return issue("unknown_module", fmt.Sprintf("módulo desconhecido %q", cmd.Module), "")
	}
	switch cmd.Action {
	case "detect", "read", "text", "sheets", "cells":
	default:
		return issue("unknown_action", fmt.Sprintf("ação desconhecida %q", cmd.Action), "")
	}
	var p basePayload
	if err := json.Unmarshal([]byte(cmd.PayloadJson), &p); err != nil {
		return issue("invalid_payload", "payload não é JSON: "+err.Error(), "")
	}
	if strings.TrimSpace(p.Path) == "" {
		return issue("invalid_payload", "path é obrigatório", "path")
	}
	if !filepath.IsAbs(p.Path) {
		return issue("invalid_payload", "path deve ser absoluto", "path")
	}
	return &extv1.ValidateResponse{Ok: true}, nil
}

func (h docs) Execute(ctx context.Context, cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	v, err := h.Validate(ctx, cmd)
	if err != nil || !v.Ok {
		return &extv1.ExecuteResponse{Ok: false, Issues: v.GetIssues()}, err
	}
	switch cmd.Action {
	case "detect":
		return runDetect(cmd)
	case "read":
		return runRead(cmd)
	case "text":
		return runText(cmd)
	case "sheets":
		return runSheets(cmd)
	case "cells":
		return runCells(cmd)
	}
	return execIssue("unsupported", "ação não suportada"), nil
}

// ---------- detect ----------

type detectResult struct {
	Path   string `json:"path"`
	Format string `json:"format"`
	Size   int64  `json:"size"`
	MIME   string `json:"mime,omitempty"`
}

func runDetect(cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var p basePayload
	_ = json.Unmarshal([]byte(cmd.PayloadJson), &p)
	info, err := os.Stat(p.Path)
	if err != nil {
		return execIssue("io_error", err.Error()), nil
	}
	if info.IsDir() {
		return execIssue("is_directory", "path aponta para diretório"), nil
	}
	format, mime := detectFormat(p.Path)
	out, _ := json.Marshal(detectResult{Path: p.Path, Format: format, Size: info.Size(), MIME: mime})
	return ok(string(out)), nil
}

func detectFormat(path string) (string, string) {
	ext := strings.ToLower(filepath.Ext(path))
	head := readHead(path, 8)
	switch {
	case bytes.HasPrefix(head, []byte("%PDF-")):
		return "pdf", "application/pdf"
	case len(head) >= 4 && bytes.Equal(head[:4], []byte{0x50, 0x4B, 0x03, 0x04}) && (ext == ".xlsx" || ext == ".xlsm"):
		return "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
	case len(head) >= 8 && bytes.Equal(head[:8], []byte{0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1}):
		return "xls", "application/vnd.ms-excel"
	}
	switch ext {
	case ".xlsx", ".xlsm":
		return "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
	case ".xls":
		return "xls", "application/vnd.ms-excel"
	case ".csv":
		return "csv", "text/csv"
	case ".tsv":
		return "tsv", "text/tab-separated-values"
	case ".pdf":
		return "pdf", "application/pdf"
	case ".json":
		return "json", "application/json"
	case ".xml":
		return "xml", "application/xml"
	case ".md", ".markdown":
		return "md", "text/markdown"
	case ".txt", ".log":
		return "txt", "text/plain"
	}
	return "unknown", ""
}

func readHead(path string, n int) []byte {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	buf := make([]byte, n)
	r, _ := f.Read(buf)
	return buf[:r]
}

// ---------- read ----------

func runRead(cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var p basePayload
	_ = json.Unmarshal([]byte(cmd.PayloadJson), &p)
	if err := guardSize(p.Path); err != nil {
		return execIssue("too_large", err.Error()), nil
	}
	format, _ := detectFormat(p.Path)
	switch format {
	case "xlsx":
		return readXLSX(p.Path)
	case "xls":
		return execIssue("unsupported_format", "xls (BIFF) ainda não suportado nesta versão; converta para xlsx"), nil
	case "csv":
		return readDelimited(p.Path, ',')
	case "tsv":
		return readDelimited(p.Path, '\t')
	case "pdf":
		return readPDF(p.Path)
	case "json":
		return readJSON(p.Path)
	case "xml":
		return readXML(p.Path)
	case "txt", "md":
		return readText(p.Path, format)
	}
	return execIssue("unsupported_format", "formato não reconhecido"), nil
}

// ---------- text (extração best-effort) ----------

func runText(cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var p basePayload
	_ = json.Unmarshal([]byte(cmd.PayloadJson), &p)
	if err := guardSize(p.Path); err != nil {
		return execIssue("too_large", err.Error()), nil
	}
	format, _ := detectFormat(p.Path)
	switch format {
	case "pdf":
		txt, err := pdfText(p.Path)
		if err != nil {
			return execIssue("parse_error", err.Error()), nil
		}
		return okMap(map[string]any{"format": format, "text": txt}), nil
	case "xlsx":
		txt, err := xlsxText(p.Path)
		if err != nil {
			return execIssue("parse_error", err.Error()), nil
		}
		return okMap(map[string]any{"format": format, "text": txt}), nil
	case "csv", "tsv", "json", "xml", "txt", "md":
		b, err := os.ReadFile(p.Path)
		if err != nil {
			return execIssue("io_error", err.Error()), nil
		}
		return okMap(map[string]any{"format": format, "text": string(b)}), nil
	}
	return execIssue("unsupported_format", "sem extrator de texto para este formato"), nil
}

// ---------- sheets / cells ----------

func runSheets(cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var p basePayload
	_ = json.Unmarshal([]byte(cmd.PayloadJson), &p)
	if format, _ := detectFormat(p.Path); format != "xlsx" {
		return execIssue("unsupported_format", "sheets só funciona em xlsx"), nil
	}
	f, err := excelize.OpenFile(p.Path)
	if err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	defer f.Close()
	return okMap(map[string]any{"sheets": f.GetSheetList()}), nil
}

func runCells(cmd *extv1.Command) (*extv1.ExecuteResponse, error) {
	var p cellsPayload
	if err := json.Unmarshal([]byte(cmd.PayloadJson), &p); err != nil {
		return execIssue("invalid_payload", err.Error()), nil
	}
	if format, _ := detectFormat(p.Path); format != "xlsx" {
		return execIssue("unsupported_format", "cells só funciona em xlsx"), nil
	}
	f, err := excelize.OpenFile(p.Path)
	if err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	defer f.Close()
	sheet := p.Sheet
	if sheet == "" {
		list := f.GetSheetList()
		if len(list) == 0 {
			return execIssue("empty", "arquivo sem abas"), nil
		}
		sheet = list[0]
	}
	rows, err := f.GetRows(sheet)
	if err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	if p.Range != "" {
		filtered, err := sliceByRange(rows, p.Range)
		if err != nil {
			return execIssue("invalid_range", err.Error()), nil
		}
		rows = filtered
	}
	return okMap(map[string]any{"sheet": sheet, "rows": rows, "row_count": len(rows)}), nil
}

func sliceByRange(rows [][]string, rng string) ([][]string, error) {
	parts := strings.Split(rng, ":")
	if len(parts) != 2 {
		return nil, fmt.Errorf("range deve estar no formato A1:C10")
	}
	c1, r1, err := excelize.CellNameToCoordinates(parts[0])
	if err != nil {
		return nil, err
	}
	c2, r2, err := excelize.CellNameToCoordinates(parts[1])
	if err != nil {
		return nil, err
	}
	if r1 > r2 || c1 > c2 {
		return nil, fmt.Errorf("range invertido")
	}
	out := [][]string{}
	for ri := r1 - 1; ri < r2 && ri < len(rows); ri++ {
		row := rows[ri]
		seg := []string{}
		for ci := c1 - 1; ci < c2; ci++ {
			if ci < len(row) {
				seg = append(seg, row[ci])
			} else {
				seg = append(seg, "")
			}
		}
		out = append(out, seg)
	}
	return out, nil
}

// ---------- parsers ----------

func readXLSX(path string) (*extv1.ExecuteResponse, error) {
	f, err := excelize.OpenFile(path)
	if err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	defer f.Close()
	sheets := map[string][][]string{}
	for _, name := range f.GetSheetList() {
		rows, err := f.GetRows(name)
		if err != nil {
			return execIssue("parse_error", fmt.Sprintf("sheet %q: %v", name, err)), nil
		}
		sheets[name] = rows
	}
	return okMap(map[string]any{"format": "xlsx", "sheets": sheets}), nil
}

func readDelimited(path string, sep rune) (*extv1.ExecuteResponse, error) {
	f, err := os.Open(path)
	if err != nil {
		return execIssue("io_error", err.Error()), nil
	}
	defer f.Close()
	r := csv.NewReader(f)
	r.Comma = sep
	r.FieldsPerRecord = -1
	rows, err := r.ReadAll()
	if err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	format := "csv"
	if sep == '\t' {
		format = "tsv"
	}
	return okMap(map[string]any{"format": format, "rows": rows, "row_count": len(rows)}), nil
}

func readPDF(path string) (*extv1.ExecuteResponse, error) {
	pages, fullText, err := pdfPages(path)
	if err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	return okMap(map[string]any{"format": "pdf", "page_count": len(pages), "pages": pages, "text": fullText}), nil
}

func pdfText(path string) (string, error) {
	_, txt, err := pdfPages(path)
	return txt, err
}

func pdfPages(path string) ([]string, string, error) {
	f, r, err := pdf.Open(path)
	if err != nil {
		return nil, "", err
	}
	defer f.Close()
	total := r.NumPage()
	pages := make([]string, 0, total)
	var all bytes.Buffer
	for i := 1; i <= total; i++ {
		page := r.Page(i)
		if page.V.IsNull() {
			pages = append(pages, "")
			continue
		}
		txt, err := page.GetPlainText(nil)
		if err != nil {
			return nil, "", fmt.Errorf("página %d: %w", i, err)
		}
		pages = append(pages, txt)
		all.WriteString(txt)
		all.WriteString("\n")
	}
	return pages, all.String(), nil
}

func xlsxText(path string) (string, error) {
	f, err := excelize.OpenFile(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	var b bytes.Buffer
	for _, name := range f.GetSheetList() {
		b.WriteString("# " + name + "\n")
		rows, err := f.GetRows(name)
		if err != nil {
			return "", err
		}
		for _, row := range rows {
			b.WriteString(strings.Join(row, "\t"))
			b.WriteString("\n")
		}
		b.WriteString("\n")
	}
	return b.String(), nil
}

func readJSON(path string) (*extv1.ExecuteResponse, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return execIssue("io_error", err.Error()), nil
	}
	var v any
	if err := json.Unmarshal(b, &v); err != nil {
		return execIssue("parse_error", err.Error()), nil
	}
	return okMap(map[string]any{"format": "json", "value": v}), nil
}

func readXML(path string) (*extv1.ExecuteResponse, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return execIssue("io_error", err.Error()), nil
	}
	return okMap(map[string]any{"format": "xml", "text": string(b)}), nil
}

func readText(path, format string) (*extv1.ExecuteResponse, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return execIssue("io_error", err.Error()), nil
	}
	return okMap(map[string]any{"format": format, "text": string(b)}), nil
}

// ---------- helpers ----------

func guardSize(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if info.Size() > maxBytes {
		return fmt.Errorf("arquivo %d bytes excede o limite de %d", info.Size(), maxBytes)
	}
	return nil
}

func ok(j string) *extv1.ExecuteResponse {
	return &extv1.ExecuteResponse{Ok: true, ResultJson: j}
}

func okMap(m map[string]any) *extv1.ExecuteResponse {
	b, _ := json.Marshal(m)
	return &extv1.ExecuteResponse{Ok: true, ResultJson: string(b)}
}

func execIssue(code, msg string) *extv1.ExecuteResponse {
	return &extv1.ExecuteResponse{Ok: false, Issues: []*extv1.Issue{{
		Severity: extv1.Issue_ERROR, Code: code, Message: msg,
	}}}
}

func issue(code, msg, path string) (*extv1.ValidateResponse, error) {
	return &extv1.ValidateResponse{Ok: false, Issues: []*extv1.Issue{{
		Severity: extv1.Issue_ERROR, Code: code, Message: msg, Path: path,
	}}}, nil
}

func main() { sdk.Serve(docs{}) }
