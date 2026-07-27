package config

import (
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"
)

const (
	defaultAddress         = ":8080"
	defaultShutdownTimeout = 10 * time.Second
)

type Config struct {
	Address         string
	LogLevel        slog.Level
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Address:         envOrDefault("BRAIN_CLOUD_ADDRESS", defaultAddress),
		LogLevel:        slog.LevelInfo,
		ShutdownTimeout: defaultShutdownTimeout,
	}

	if value := os.Getenv("BRAIN_CLOUD_LOG_LEVEL"); value != "" {
		if err := cfg.LogLevel.UnmarshalText([]byte(strings.ToUpper(value))); err != nil {
			return Config{}, fmt.Errorf("BRAIN_CLOUD_LOG_LEVEL: %w", err)
		}
	}

	if value := os.Getenv("BRAIN_CLOUD_SHUTDOWN_TIMEOUT"); value != "" {
		duration, err := time.ParseDuration(value)
		if err != nil {
			return Config{}, fmt.Errorf("BRAIN_CLOUD_SHUTDOWN_TIMEOUT: %w", err)
		}
		if duration <= 0 {
			return Config{}, fmt.Errorf("BRAIN_CLOUD_SHUTDOWN_TIMEOUT must be positive")
		}
		cfg.ShutdownTimeout = duration
	}

	return cfg, nil
}

func envOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
