package validate

import (
	"context"
	"fmt"
	"regexp"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	container "cloud.google.com/go/container/apiv1"
	"cloud.google.com/go/container/apiv1/containerpb"
)

var (
	instanceSelfLinkRegexp             = regexp.MustCompile(`https:\/\/www\.googleapis\.com\/compute\/v1\/projects\/(.+?)\/zones\/(.+?)\/instances\/(.+)`)
	instanceGroupManagerSelfLinkRegexp = regexp.MustCompile(`https:\/\/www\.googleapis\.com\/compute\/v1\/projects\/(.+?)\/zones\/(.+?)\/instanceGroupManagers\/(.+)`)
	instanceTemplateSelfLinkRegexp     = regexp.MustCompile(`https:\/\/www\.googleapis\.com\/compute\/v1\/projects\/(.+?)\/regions\/(.+?)\/instanceTemplates\/(.+)`)
)

type InstanceTemplateWhitelistProvider struct {
	gcpClusterClient               *container.ClusterManagerClient
	gcpInstanceGroupManagersClient *compute.InstanceGroupManagersClient
	gcpInstanceTemplateClient      *compute.RegionInstanceTemplatesClient
}

func NewInstanceTemplateWhitelistProvider(cmc *container.ClusterManagerClient, igmc *compute.InstanceGroupManagersClient, itc *compute.RegionInstanceTemplatesClient) (*InstanceTemplateWhitelistProvider, error) {

	return &InstanceTemplateWhitelistProvider{
		gcpClusterClient:               cmc,
		gcpInstanceGroupManagersClient: igmc,
		gcpInstanceTemplateClient:      itc,
	}, nil
}

func (c *InstanceTemplateWhitelistProvider) GetWhitelist(ctx context.Context, instance *computepb.Instance) ([]string, error) {
	instanceTemplate, err := c.getInstanceTemplate(ctx, instance)
	if err != nil {
		return nil, fmt.Errorf("failed to get instance template: %w", err)
	}

	configureSh, err := findMetadata(instanceTemplate.Properties.GetMetadata(), MetadataConfigureShKey)
	if err != nil {
		return nil, fmt.Errorf("failed to get configure-sh from instance template: %w", err)
	}

	userData, err := findMetadata(instanceTemplate.Properties.GetMetadata(), MetadataUserDataKey)
	if err != nil {
		return nil, fmt.Errorf("failed to get user-data from instance template: %w", err)
	}

	return []string{configureSh, userData}, nil
}

func (c *InstanceTemplateWhitelistProvider) getInstanceTemplate(ctx context.Context, instance *computepb.Instance) (*computepb.InstanceTemplate, error) {
	clusterName, found := instance.Labels["goog-k8s-cluster-name"]
	if !found {
		return nil, fmt.Errorf("cluster name not found")
	}

	nodePoolName, found := instance.Labels["goog-k8s-node-pool-name"]
	if !found {
		return nil, fmt.Errorf("node pool name not found")
	}

	projectID, zone, _, err := parseInstanceSelfLink(instance.GetSelfLink())
	if err != nil {
		return nil, fmt.Errorf("failed to parse instance self link: %w", err)
	}
	location := parseLocationFromZone(zone)

	nodePoolURI := fmt.Sprintf("projects/%s/locations/%s/clusters/%s/nodePools/%s", projectID, location, clusterName, nodePoolName)

	np, err := c.gcpClusterClient.GetNodePool(ctx, &containerpb.GetNodePoolRequest{
		Name: nodePoolURI,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get node pool: %w", err)
	}

	instanceGroupURL, err := findInstanceGroupUrlForZone(np.InstanceGroupUrls, zone)
	if err != nil {
		return nil, fmt.Errorf("failed to find instance group for zone: %w", err)
	}

	_, _, instanceGroupName, err := parseInstanceGroupManagerSelfLink(instanceGroupURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse instance group manager self link: %w", err)
	}

	img, err := c.gcpInstanceGroupManagersClient.Get(ctx, &computepb.GetInstanceGroupManagerRequest{
		Project:              projectID,
		Zone:                 zone,
		InstanceGroupManager: instanceGroupName,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get instance group manager: %w", err)
	}

	_, _, instanceTemplateName, err := parseInstanceTemplateSelfLink(img.GetInstanceTemplate())
	if err != nil {
		return nil, fmt.Errorf("failed to parse instance template self link: %w", err)
	}

	instanceTemplate, err := c.gcpInstanceTemplateClient.Get(ctx, &computepb.GetRegionInstanceTemplateRequest{
		Project:          projectID,
		Region:           location,
		InstanceTemplate: instanceTemplateName,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get instance template: %w", err)
	}

	return instanceTemplate, nil
}

func findInstanceGroupUrlForZone(instanceGroupUrls []string, zone string) (string, error) {
	for _, url := range instanceGroupUrls {
		_, z, _, err := parseInstanceGroupManagerSelfLink(url)
		if err != nil {
			return "", fmt.Errorf("failed to parse instance group manager self link: %w", err)
		}

		if z == zone {
			return url, nil
		}
	}

	return "", fmt.Errorf("instance group manager not found for zone")
}

func parseInstanceSelfLink(link string) (string, string, string, error) {
	matches := instanceSelfLinkRegexp.FindStringSubmatch(link)
	if len(matches) != 4 {
		return "", "", "", fmt.Errorf("invalid instance self link")
	}

	return matches[1], matches[2], matches[3], nil
}

func parseInstanceGroupManagerSelfLink(link string) (string, string, string, error) {
	matches := instanceGroupManagerSelfLinkRegexp.FindStringSubmatch(link)
	if len(matches) != 4 {
		return "", "", "", fmt.Errorf("invalid instance group manager self link")
	}

	return matches[1], matches[2], matches[3], nil
}

func parseInstanceTemplateSelfLink(link string) (string, string, string, error) {
	matches := instanceTemplateSelfLinkRegexp.FindStringSubmatch(link)
	if len(matches) != 4 {
		return "", "", "", fmt.Errorf("invalid instance template self link")
	}

	return matches[1], matches[2], matches[3], nil
}

func parseLocationFromZone(zone string) string {
	return zone[:len(zone)-2]
}
