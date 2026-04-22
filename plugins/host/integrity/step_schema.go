package integrity

import (
	"context"
	"encoding/json"
	"fmt"
)

// SchemaStep valida cmd.PayloadJson contra o JSON Schema declarado em Capability.
// Fase 2: implementação leve sem dependência externa — cobre type/required/properties
// e tipos básicos (string, number, boolean, object, array). O suficiente para plugins
// internos; substituir por validador completo quando abrirmos para plugins de terceiros.
type SchemaStep struct{}

func (SchemaStep) Name() string { return "schema" }

func (SchemaStep) Check(_ context.Context, pc *Context) error {
	if pc.Capability == nil || pc.Capability.SchemaPayload == "" {
		return nil // sem schema declarado: skip
	}
	var schema map[string]any
	if err := json.Unmarshal([]byte(pc.Capability.SchemaPayload), &schema); err != nil {
		return fmt.Errorf("schema inválido do plugin: %w", err)
	}
	var payload any
	if err := json.Unmarshal([]byte(pc.Cmd.PayloadJson), &payload); err != nil {
		return fmt.Errorf("payload não é JSON: %w", err)
	}
	return validate(schema, payload, "$")
}

func validate(schema map[string]any, value any, path string) error {
	if t, ok := schema["type"].(string); ok {
		if err := checkType(t, value, path); err != nil {
			return err
		}
	}
	if props, ok := schema["properties"].(map[string]any); ok {
		obj, ok := value.(map[string]any)
		if !ok {
			return nil // type já reportou se não bateu
		}
		if req, ok := schema["required"].([]any); ok {
			for _, r := range req {
				key, _ := r.(string)
				if _, present := obj[key]; !present {
					return fmt.Errorf("%s: campo obrigatório %q ausente", path, key)
				}
			}
		}
		for k, sub := range props {
			subSchema, _ := sub.(map[string]any)
			if v, present := obj[k]; present && subSchema != nil {
				if err := validate(subSchema, v, path+"."+k); err != nil {
					return err
				}
			}
		}
	}
	if items, ok := schema["items"].(map[string]any); ok {
		arr, _ := value.([]any)
		for i, v := range arr {
			if err := validate(items, v, fmt.Sprintf("%s[%d]", path, i)); err != nil {
				return err
			}
		}
	}
	return nil
}

func checkType(want string, value any, path string) error {
	ok := false
	switch want {
	case "string":
		_, ok = value.(string)
	case "number", "integer":
		_, ok = value.(float64)
	case "boolean":
		_, ok = value.(bool)
	case "object":
		_, ok = value.(map[string]any)
	case "array":
		_, ok = value.([]any)
	case "null":
		ok = value == nil
	default:
		ok = true
	}
	if !ok {
		return fmt.Errorf("%s: esperado %s, recebeu %T", path, want, value)
	}
	return nil
}
