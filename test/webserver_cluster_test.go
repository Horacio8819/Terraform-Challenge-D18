package test

import (
	"fmt"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestWebserverCluster(t *testing.T) {
	t.Parallel()

	uniqueID := random.UniqueId()
	clusterName := fmt.Sprintf("test-cluster-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":            clusterName,
			"environment":             "production",
			"create_dns_record":       false,
			"aws_region":              "eu-central-1",
			"project_name":            "devops-project",
			"team_name":               "devOps",
			"alert_email":             "horace.djousse@yahoo.com",
			"server_template_version": "latest",

			"public_subnets": map[string]interface{}{
				"a": "172.31.108.0/24",
				"b": "172.31.109.0/24",
				"c": "172.31.110.0/24",
			},
		},
	})
	// Always destroy at the end, even if assertions fail
	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// Retry for up to 5 minutes — ALB takes time to register instances
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,
		10*time.Second,
		func(status int, body string) bool {
			return status == 200 && len(body) > 0
		},
	)

	// Assert the output is defined and non-empty
	assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")

}
