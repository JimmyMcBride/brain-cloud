package server

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
)

func TestEndpoints(t *testing.T) {
	handler := New(slog.New(slog.NewTextHandler(io.Discard, nil)))

	tests := []struct {
		name string
		path string
		want any
	}{
		{"health", "/healthz", map[string]string{"status": "ok"}},
		{"readiness", "/readyz", map[string]string{"status": "ready"}},
		{"system info", "/v1/system/info", systemInfo{
			Server:          "brain-cloud",
			ServerVersion:   "0.0.0-dev",
			ProtocolVersion: "v1",
			Capabilities:    []string{"system.info"},
			Modules:         []string{},
		}},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, test.path, nil)
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)

			if response.Code != http.StatusOK {
				t.Fatalf("status = %d", response.Code)
			}
			if contentType := response.Header().Get("Content-Type"); contentType != "application/json" {
				t.Fatalf("content type = %q", contentType)
			}

			var target any
			switch test.want.(type) {
			case systemInfo:
				target = &systemInfo{}
			default:
				target = &map[string]string{}
			}
			if err := json.Unmarshal(response.Body.Bytes(), target); err != nil {
				t.Fatal(err)
			}
			var got any
			switch value := target.(type) {
			case *systemInfo:
				got = *value
			case *map[string]string:
				got = *value
			}
			if !reflect.DeepEqual(got, test.want) {
				t.Fatalf("body = %#v, want %#v", got, test.want)
			}
		})
	}
}

func TestUnknownEndpoint(t *testing.T) {
	handler := New(slog.New(slog.NewTextHandler(io.Discard, nil)))
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/missing", nil))
	if response.Code != http.StatusNotFound {
		t.Fatalf("status = %d", response.Code)
	}
}
