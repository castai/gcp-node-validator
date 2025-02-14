package validate_test

import (
	"context"
	"testing"

	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/castai/gcp-node-validator/container/validate"
	"github.com/samber/lo"
	"github.com/stretchr/testify/require"
)

type mockWhitelistProvider struct {
	whitelist []string
}

func (m *mockWhitelistProvider) GetWhitelist(ctx context.Context, instance *computepb.Instance) ([]string, error) {
	return m.whitelist, nil
}

func TestInstanceValidatorValidate(t *testing.T) {
	t.Parallel()
	type fields struct {
		whitelistProvider validate.WhitelistProvider
	}
	type args struct {
		ctx      context.Context
		instance *computepb.Instance
	}
	tests := []struct {
		name   string
		fields fields
		args   args
		err    error
	}{
		{
			name: "success",
			fields: fields{
				whitelistProvider: &mockWhitelistProvider{
					whitelist: []string{"echo 'hello world'", "echo 'foo bar'"},
				},
			},
			args: args{
				ctx: context.Background(),
				instance: &computepb.Instance{
					Metadata: &computepb.Metadata{
						Items: []*computepb.Items{
							{
								Key:   lo.ToPtr("configure-sh"),
								Value: lo.ToPtr("echo 'hello world'"),
							},
							{
								Key:   lo.ToPtr("user-data"),
								Value: lo.ToPtr("echo 'foo bar'"),
							},
						},
					},
				},
			},
		},
		{
			name: "failure in configure-sh",
			fields: fields{
				whitelistProvider: &mockWhitelistProvider{
					whitelist: []string{"echo 'hello world'"},
				},
			},
			args: args{
				ctx: context.Background(),
				instance: &computepb.Instance{
					Metadata: &computepb.Metadata{
						Items: []*computepb.Items{
							{
								Key:   lo.ToPtr("configure-sh"),
								Value: lo.ToPtr("echo 'hello world'"),
							},
							{
								Key:   lo.ToPtr("user-data"),
								Value: lo.ToPtr("echo 'strange code'"),
							},
						},
					},
				},
			},
			err: &validate.ValidationError{UnknownCommands: "echo 'strange code'"},
		},
		{
			name: "failure in user-data",
			fields: fields{
				whitelistProvider: &mockWhitelistProvider{
					whitelist: []string{"echo 'foo bar'"},
				},
			},
			args: args{
				ctx: context.Background(),
				instance: &computepb.Instance{
					Metadata: &computepb.Metadata{
						Items: []*computepb.Items{
							{
								Key:   lo.ToPtr("configure-sh"),
								Value: lo.ToPtr("echo 'foo bar'"),
							},
							{
								Key:   lo.ToPtr("user-data"),
								Value: lo.ToPtr("echo 'strange code'"),
							},
						},
					},
				},
			},
			err: &validate.ValidationError{UnknownCommands: "echo 'strange code'"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := require.New(t)
			v := validate.NewInstanceValidator(tt.fields.whitelistProvider)

			err := v.Validate(tt.args.ctx, tt.args.instance)

			if tt.err != nil {
				r.Error(err)
				var validationErr *validate.ValidationError
				r.ErrorAs(err, &validationErr)
				r.Equal(tt.err, validationErr)
			} else {
				r.NoError(err)
			}
		})
	}
}

