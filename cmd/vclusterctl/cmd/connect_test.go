package cmd

import (
	"testing"

	"github.com/loft-sh/vcluster/cmd/vclusterctl/flags"
	"gotest.tools/v3/assert"
	clientcmdapi "k8s.io/client-go/tools/clientcmd/api"
)

const (
	defaultContextName = "my-vcluster"
)

func TestExchangeContextName(t *testing.T) {
	vclusterName := "vcluster-name"
	namespace := "default"
	defaultContext := &clientcmdapi.Config{
		Clusters: map[string]*clientcmdapi.Cluster{
			defaultContextName: {Server: "foo"},
		},
		AuthInfos: map[string]*clientcmdapi.AuthInfo{
			defaultContextName: {
				Token: "foo",
			},
		},
		Contexts: map[string]*clientcmdapi.Context{
			defaultContextName: {
				Cluster:  defaultContextName,
				AuthInfo: defaultContextName,
			},
		},
		CurrentContext: defaultContextName,
	}
	testTable := []struct {
		desc           string
		newContextName string
		config         *clientcmdapi.Config
		expectedConfig *clientcmdapi.Config
	}{
		{
			desc:           "KubeConfigContextName specified",
			newContextName: "new-context",
			config:         defaultContext.DeepCopy(),
			expectedConfig: &clientcmdapi.Config{
				Clusters: map[string]*clientcmdapi.Cluster{
					"new-context": {Server: "foo"},
				},
				AuthInfos: map[string]*clientcmdapi.AuthInfo{
					"new-context": {
						Token: "foo",
					},
				},
				Contexts: map[string]*clientcmdapi.Context{
					"new-context": {
						Cluster:  "new-context",
						AuthInfo: "new-context",
					},
				},
				CurrentContext: "new-context",
			},
		},
		{
			desc:           "KubeConfigContextName same as default",
			newContextName: defaultContextName,
			config:         defaultContext.DeepCopy(),
			expectedConfig: &clientcmdapi.Config{
				Clusters: map[string]*clientcmdapi.Cluster{
					defaultContextName: {Server: "foo"},
				},
				AuthInfos: map[string]*clientcmdapi.AuthInfo{
					defaultContextName: {
						Token: "foo",
					},
				},
				Contexts: map[string]*clientcmdapi.Context{
					defaultContextName: {
						Cluster:  defaultContextName,
						AuthInfo: defaultContextName,
					},
				},
				CurrentContext: defaultContextName,
			},
		},
	}

	for _, testCase := range testTable {
		cmd := &ConnectCmd{
			GlobalFlags: &flags.GlobalFlags{
				Namespace: namespace,
			},
			KubeConfigContextName: testCase.newContextName,
		}
		assert.NilError(t, cmd.exchangeContextName(testCase.config, vclusterName))
		newConfig := testCase.config.DeepCopy()

		assert.DeepEqual(t, newConfig, testCase.expectedConfig)
	}
}
