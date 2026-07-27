package config

import (
	"log/slog"
	"testing"
	"time"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("BRAIN_CLOUD_ADDRESS", "")
	t.Setenv("BRAIN_CLOUD_LOG_LEVEL", "")
	t.Setenv("BRAIN_CLOUD_SHUTDOWN_TIMEOUT", "")

	cfg, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Address != ":8080" || cfg.LogLevel != slog.LevelInfo || cfg.ShutdownTimeout != 10*time.Second {
		t.Fatalf("unexpected defaults: %#v", cfg)
	}
}

func TestLoadRejectsInvalidTimeout(t *testing.T) {
	t.Setenv("BRAIN_CLOUD_SHUTDOWN_TIMEOUT", "later")
	if _, err := Load(); err == nil {
		t.Fatal("expected an error")
	}
}
