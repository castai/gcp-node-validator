package validate

import (
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestValidateConfigureSh(t *testing.T) {
	t.Parallel()
	r := require.New(t)

	t.Run("wrong script", func(t *testing.T) {
		t.Parallel()

		configureSh, err := os.ReadFile("./testfile/wrong-configure.sh")
		r.NoError(err)

		err = ValidateConfigureSh(string(configureSh))
		r.Error(err)
	})

	t.Run("correct script", func(t *testing.T) {
		t.Parallel()

		configureSh, err := os.ReadFile("./testfile/configure.sh")
		r.NoError(err)

		err = ValidateConfigureSh(string(configureSh))
		r.NoError(err)
	})
}
