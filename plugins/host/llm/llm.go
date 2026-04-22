// Package llm — cliente OpenAI-compatible. Funciona com: OpenAI, Groq,
// OpenRouter, Together, DeepSeek, Fireworks, Ollama (/v1), LM Studio,
// Azure OpenAI (com base_url apropriada) e qualquer gateway que siga o
// schema /chat/completions.
package llm

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type ProviderSpec struct {
	Name    string            `json:"name"`              // id lógico
	BaseURL string            `json:"base_url"`          // ex: https://api.openai.com/v1
	APIKey  string            `json:"api_key,omitempty"` // Bearer
	Model   string            `json:"model"`
	Headers map[string]string `json:"headers,omitempty"` // headers extras (x-api-key etc.)
	Timeout time.Duration     `json:"timeout,omitempty"`
}

type Message struct {
	Role       string     `json:"role"` // system|user|assistant|tool
	Content    string     `json:"content,omitempty"`
	ToolCalls  []ToolCall `json:"tool_calls,omitempty"`
	ToolCallID string     `json:"tool_call_id,omitempty"`
	Name       string     `json:"name,omitempty"`
}

type ToolCall struct {
	ID       string       `json:"id"`
	Type     string       `json:"type"` // "function"
	Function FunctionCall `json:"function"`
}

type FunctionCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"` // JSON string
}

type Tool struct {
	Type     string       `json:"type"` // "function"
	Function FunctionDecl `json:"function"`
}

type FunctionDecl struct {
	Name        string          `json:"name"`
	Description string          `json:"description,omitempty"`
	Parameters  json.RawMessage `json:"parameters"` // JSON Schema
}

type ChatRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Tools       []Tool    `json:"tools,omitempty"`
	Temperature *float64  `json:"temperature,omitempty"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
}

type ChatResponse struct {
	Choices []struct {
		Index        int     `json:"index"`
		Message      Message `json:"message"`
		FinishReason string  `json:"finish_reason"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error,omitempty"`
}

type Client struct {
	spec   ProviderSpec
	client *http.Client
}

func New(spec ProviderSpec) *Client {
	to := spec.Timeout
	if to == 0 {
		to = 2 * time.Minute
	}
	return &Client{spec: spec, client: &http.Client{Timeout: to}}
}

func (c *Client) Name() string  { return c.spec.Name }
func (c *Client) Model() string { return c.spec.Model }

func (c *Client) Chat(ctx context.Context, req ChatRequest) (*ChatResponse, error) {
	if req.Model == "" {
		req.Model = c.spec.Model
	}
	body, _ := json.Marshal(req)
	url := c.spec.BaseURL + "/chat/completions"
	hreq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	hreq.Header.Set("Content-Type", "application/json")
	if c.spec.APIKey != "" {
		hreq.Header.Set("Authorization", "Bearer "+c.spec.APIKey)
	}
	for k, v := range c.spec.Headers {
		hreq.Header.Set(k, v)
	}
	resp, err := c.client.Do(hreq)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("llm[%s] http %d: %s", c.spec.Name, resp.StatusCode, string(raw))
	}
	var out ChatResponse
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, fmt.Errorf("llm[%s] parse: %w (%s)", c.spec.Name, err, string(raw))
	}
	if out.Error != nil {
		return nil, fmt.Errorf("llm[%s] erro: %s", c.spec.Name, out.Error.Message)
	}
	if len(out.Choices) == 0 {
		return nil, fmt.Errorf("llm[%s] sem choices", c.spec.Name)
	}
	return &out, nil
}
