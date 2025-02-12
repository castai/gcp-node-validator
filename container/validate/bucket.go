package validate

import (
	"context"
	"fmt"
	"io"

	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/storage"
	"github.com/sirupsen/logrus"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

type CloudStorageWhitelistGetter struct {
	bucketName            string
	objectPrefix          string
	gcpCloudStorageClient *storage.Client
}

func NewCloudStorageWhitelistGetter(bucketName string, options []option.ClientOption) (*CloudStorageWhitelistGetter, error) {
	gcpCloudStorageClient, err := storage.NewClient(context.Background(), options...)
	if err != nil {
		return nil, err
	}

	return &CloudStorageWhitelistGetter{
		bucketName:            bucketName,
		objectPrefix:          "",
		gcpCloudStorageClient: gcpCloudStorageClient,
	}, nil
}

func (c *CloudStorageWhitelistGetter) GetWhitelist(ctx context.Context, i *computepb.Instance) ([]string, error) {
	objIterator := c.gcpCloudStorageClient.Bucket(c.bucketName).Objects(ctx, &storage.Query{
		Prefix: c.objectPrefix,
	})

	whitelist := []string{}

	for {
		attrs, err := objIterator.Next()
		if err == iterator.Done {
			break
		}

		if err != nil {
			return nil, fmt.Errorf("failed to get object: %v", err)
		}

		if attrs.Size > 1024*1024 {
			logrus.WithFields(logrus.Fields{
				"object": attrs.Name,
				"size":   attrs.Size,
			}).Infof("skipping object because it is too large")
			continue
		}

		reader, err := c.gcpCloudStorageClient.Bucket(c.bucketName).Object(attrs.Name).NewReader(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to get object reader: %v", err)
		}
		defer reader.Close()

		data, err := io.ReadAll(reader)
		if err != nil {
			return nil, fmt.Errorf("failed to read object: %v", err)
		}

		whitelist = append(whitelist, string(data))
	}

	return whitelist, nil
}
