package validate

import (
	"errors"
	"fmt"
	"regexp"

	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/sergi/go-diff/diffmatchpatch"
)

type scriptCleaner interface {
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

var configureShCleaners = []scriptCleaner{
	NewRegexReplacement(`DEFAULT_CNI_VERSION='.+'`, `DEFAULT_CNI_VERSION=`),
	NewRegexReplacement(`DEFAULT_CNI_HASH_LINUX_AMD64='.+'`, `DEFAULT_CNI_HASH_LINUX_AMD64=`),
	NewRegexReplacement(`DEFAULT_CNI_HASH_LINUX_ARM64='.+'`, `DEFAULT_CNI_HASH_LINUX_ARM64=`),
	NewRegexReplacement(`DEFAULT_NPD_VERSION='.+'`, `DEFAULT_NPD_VERSION=`),
	NewRegexReplacement(`DEFAULT_NPD_HASH_AMD64='.+'`, `DEFAULT_NPD_HASH_AMD64=`),
	NewRegexReplacement(`DEFAULT_NPD_HASH_ARM64='.+'`, `DEFAULT_NPD_HASH_ARM64=`),
	NewRegexReplacement(`DEFAULT_CRICTL_VERSION='.+'`, `DEFAULT_CRICTL_VERSION=`),
	NewRegexReplacement(`DEFAULT_CRICTL_AMD64_SHA512='.+'`, `DEFAULT_CRICTL_AMD64_SHA512=`),
	NewRegexReplacement(`DEFAULT_CRICTL_ARM64_SHA512='.+'`, `DEFAULT_CRICTL_ARM64_SHA512=`),
	NewRegexReplacement(`NPD_CUSTOM_PLUGINS_VERSION=".+"`, `NPD_CUSTOM_PLUGINS_VERSION=`),
	NewRegexReplacement(`NPD_CUSTOM_PLUGINS_TAR_AMD64_HASH=".+"`, `NPD_CUSTOM_PLUGINS_TAR_AMD64_HASH=`),
	NewRegexReplacement(`NPD_CUSTOM_PLUGINS_TAR_ARM64_HASH=".+"`, `NPD_CUSTOM_PLUGINS_TAR_ARM64_HASH=`),
	NewRegexReplacement(`RIPTIDE_FUSE_VERSION=".+"`, `RIPTIDE_FUSE_VERSION=`),
	NewRegexReplacement(`AUTH_PROVIDER_GCP_VERSION=".+"`, `AUTH_PROVIDER_GCP_VERSION=`),
	NewRegexReplacement(`AUTH_PROVIDER_GCP_HASH_LINUX_AMD64=".+"`, `AUTH_PROVIDER_GCP_HASH_LINUX_AMD64=`),
	NewRegexReplacement(`AUTH_PROVIDER_GCP_HASH_LINUX_ARM64=".+"`, `AUTH_PROVIDER_GCP_HASH_LINUX_ARM64=`),
	NewRegexReplacement(`RIPTIDE_SNAPSHOTTER_VERSION=".+"`, `RIPTIDE_SNAPSHOTTER_VERSION=`),
	NewRegexReplacement(`DEFAULT_MOUNTER_ROOTFS_VERSION='.+'`, `DEFAULT_MOUNTER_ROOTFS_VERSION=`),
	NewRegexReplacement(`DEFAULT_MOUNTER_ROOTFS_TAR_AMD64_SHA512='.+'`, `DEFAULT_MOUNTER_ROOTFS_TAR_AMD64_SHA512=`),
	NewRegexReplacement(`DEFAULT_MOUNTER_ROOTFS_TAR_ARM64_SHA512='.+'`, `DEFAULT_MOUNTER_ROOTFS_TAR_ARM64_SHA512=`),
	NewRegexReplacement(`RIPTIDE_FUSE_ARM64_SHA512='.+'`, `RIPTIDE_FUSE_ARM64_SHA512=`),
	NewRegexReplacement(`RIPTIDE_FUSE_BIN_ARM64_SHA512='.+'`, `RIPTIDE_FUSE_BIN_ARM64_SHA512=`),
	NewRegexReplacement(`RIPTIDE_FUSE_AMD64_SHA512='.+'`, `RIPTIDE_FUSE_AMD64_SHA512=`),
	NewRegexReplacement(`RIPTIDE_FUSE_BIN_AMD64_SHA512='.+'`, `RIPTIDE_FUSE_BIN_AMD64_SHA512=`),
	NewRegexReplacement(`RIPTIDE_SNAPSHOTTER_SHA512='.+'`, `RIPTIDE_SNAPSHOTTER_SHA512=`),
	NewRegexReplacement(`RIPTIDE_SNAPSHOTTER_BIN_ARM64_SHA512='.+'`, `RIPTIDE_SNAPSHOTTER_BIN_ARM64_SHA512=`),
	NewRegexReplacement(`RIPTIDE_SNAPSHOTTER_BIN_AMD64_SHA512='.+'`, `RIPTIDE_SNAPSHOTTER_BIN_AMD64_SHA512=`),
	NewRegexReplacement(`GKE_CONTAINERD_INFRA_CONTAINER=".+"`, `GKE_CONTAINERD_INFRA_CONTAINER=`),

	NewRegexReplacement(`CASTAI_API_KEY=".+"`, `CASTAI_API_KEY=`),
	NewRegexReplacement(`CASTAI_CLUSTER_ID=".+"`, `CASTAI_CLUSTER_ID=`),
	NewRegexReplacement(`CASTAI_NODE_ID=".+"`, `CASTAI_NODE_ID=`),
	NewRegexReplacement(`-H "X-Api-Key: .+?"`, `-H "X-Api-Key: ****"`),
	NewRegexReplacement(`https://api.cast.ai/v1/kubernetes/external-clusters/.+?/nodes/.+?/logs`, `https://api.cast.ai/v1/kubernetes/external-clusters/****/nodes/****/logs`),
}

type ValidateError struct {
	diffs string
}

func (e *ValidateError) Error() string {
	return fmt.Sprintf("validation failed, diff: %v", e.diffs)
}

func ValidateConfigureSh(configureSh string) error {
	for _, cleaner := range configureShCleaners {
		configureSh = cleaner.Apply(configureSh)
	}

	if goldenConfigureSh == configureSh {
		return nil
	}

	dmp := diffmatchpatch.New()
	diffs := dmp.DiffMain(goldenConfigureSh, configureSh, false)
	return &ValidateError{
		diffs: dmp.DiffPrettyText(diffs),
	}
}

var (
	ErrMetadataNotFound = errors.New("metadata not found")
)

const (
	MetadataConfigureShKey = "configure-sh"
)

type InstanceValidator struct {
}

func NewInstanceValidator() *InstanceValidator {
	return &InstanceValidator{}
}

func (v *InstanceValidator) Validate(i *computepb.Instance) error {
	configureSh, err := v.findMetadata(i, MetadataConfigureShKey)
	if err != nil {
		return fmt.Errorf("failed to find metadata: %w", err)
	}

	if err := ValidateConfigureSh(configureSh); err != nil {
		return fmt.Errorf("failed to validate configure.sh: %w", err)
	}

	return nil
}

func (v *InstanceValidator) findMetadata(i *computepb.Instance, key string) (string, error) {
	items := i.Metadata.GetItems()
	for _, item := range items {
		if item.GetKey() == key {
			return item.GetValue(), nil
		}
	}
	return "", ErrMetadataNotFound
}
