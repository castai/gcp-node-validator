package validate

import (
	_ "embed"
)

//go:embed golden/configure.sh
var goldenConfigureSh string
