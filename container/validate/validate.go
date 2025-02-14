package validate

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"cloud.google.com/go/compute/apiv1/computepb"
)

type WhitelistProvider interface {
	GetWhitelist(ctx context.Context, instance *computepb.Instance) ([]string, error)
}

type scriptPreprocessor interface {
	Apply(string) string
}

type RegexpReplacement struct {
	regexp *regexp.Regexp
	repl   string
}

func NewRegexReplacement(pattern, repl string) *RegexpReplacement {
	return &RegexpReplacement{
		regexp: regexp.MustCompile(pattern),
		repl:   repl,
	}

}

func (rr *RegexpReplacement) Apply(s string) string {
	return rr.regexp.ReplaceAllString(s, rr.repl)
}

var configureShPreprocessors = []scriptPreprocessor{
	NewRegexReplacement(`CASTAI_API_KEY=".+"`, `CASTAI_API_KEY=****`),
	NewRegexReplacement(`CASTAI_CLUSTER_ID=".+"`, `CASTAI_CLUSTER_ID=****`),
	NewRegexReplacement(`CASTAI_NODE_ID=".+"`, `CASTAI_NODE_ID=****`),
	NewRegexReplacement(`-H "X-Api-Key: .+?"`, `-H "X-Api-Key: ****"`),
	NewRegexReplacement(`https://.+?/v1/kubernetes/external-clusters/.+?/nodes/.+?/logs`, `https://****/v1/kubernetes/external-clusters/****/nodes/****/logs`),
}

type ValidationError struct {
	UnknownCommands string
}

func (e *ValidationError) Error() string {
	return "validation failed"
}

var (
	ErrMetadataNotFound = errors.New("metadata not found")
)

const (
	MetadataConfigureShKey = "configure-sh"
	MetadataUserDataKey    = "user-data"
)

type InstanceValidator struct {
	providers []WhitelistProvider
}

func NewInstanceValidator(providers ...WhitelistProvider) *InstanceValidator {
	return &InstanceValidator{
		providers: providers,
	}
}

func (v *InstanceValidator) Validate(ctx context.Context, i *computepb.Instance) error {
	whitelist := []string{}
	for _, provider := range v.providers {
		w, err := provider.GetWhitelist(ctx, i)
		if err != nil {
			return fmt.Errorf("failed to get whitelist: %w", err)
		}

		whitelist = append(whitelist, w...)
	}

	configureSh, err := findMetadata(i.Metadata, MetadataConfigureShKey)
	if err != nil {
		return fmt.Errorf("failed to find metadata: %w", err)
	}

	if err := v.validateConfigureSh(whitelist, configureSh); err != nil {
		return fmt.Errorf("failed to validate configure-sh: %w", err)
	}

	userData, err := findMetadata(i.Metadata, MetadataUserDataKey)
	if err != nil {
		return fmt.Errorf("failed to find metadata: %w", err)
	}

	if err := v.validateUserData(whitelist, userData); err != nil {
		return fmt.Errorf("failed to validate user-data: %w", err)
	}

	return nil
}

func (v *InstanceValidator) validateConfigureSh(whitelist []string, configureSh string) error {
	for _, processor := range configureShPreprocessors {
		configureSh = processor.Apply(configureSh)
	}

	for _, w := range whitelist {
		configureSh = strings.ReplaceAll(configureSh, w, "")
	}

	if strings.TrimSpace(configureSh) == "" {
		return nil
	}

	return &ValidationError{UnknownCommands: configureSh}
}

func (v *InstanceValidator) validateUserData(whitelist []string, userData string) error {
	for _, w := range whitelist {
		userData = strings.ReplaceAll(userData, w, "")
	}

	if strings.TrimSpace(userData) == "" {
		return nil
	}

	return &ValidationError{UnknownCommands: userData}
}

func findMetadata(m *computepb.Metadata, key string) (string, error) {
	items := m.GetItems()
	for _, item := range items {
		if item.GetKey() == key {
			return item.GetValue(), nil
		}
	}
	return "", ErrMetadataNotFound
}
