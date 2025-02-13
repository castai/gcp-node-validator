package validate

import (
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"time"

	"cloud.google.com/go/compute/apiv1/computepb"
	"cloud.google.com/go/storage"
	"github.com/patrickmn/go-cache"
	"github.com/sirupsen/logrus"
	"google.golang.org/api/iterator"
)

type CloudStorageWhitelistGetter struct {
	bucketName            string
	objectPrefix          string
	gcpCloudStorageClient *storage.Client

	objCache *cache.Cache
}

func NewCloudStorageWhitelistGetter(bucketName string, gcsc *storage.Client, objCacheTTL time.Duration) (*CloudStorageWhitelistGetter, error) {
	c := cache.New(objCacheTTL, 2*objCacheTTL)

	return &CloudStorageWhitelistGetter{
		bucketName:            bucketName,
		objectPrefix:          "",
		gcpCloudStorageClient: gcsc,
		objCache:              c,
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

		log := logrus.WithField("objectName", attrs.Name)

		cacheKey := fmt.Sprintf("%s:%s", attrs.Name, base64.StdEncoding.EncodeToString(attrs.MD5))
		cachedObj, found := c.objCache.Get(cacheKey)
		if found {
			cachedObjData, ok := cachedObj.([]byte)
			if ok {
				log.Debug("using cached object")
				whitelist = append(whitelist, string(cachedObjData))
				continue
			}
		}

		if attrs.Size == 0 {
			continue
		}

		if attrs.Size > 1024*1024 {
			log.WithField("size", attrs.Size).Infof("skipping object because it is too large")
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

		c.objCache.Set(cacheKey, data, cache.DefaultExpiration)

		whitelist = append(whitelist, string(data))
	}

	return whitelist, nil
}
