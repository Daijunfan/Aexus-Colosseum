//go:build !linux

package resolver

import (
	"runtime"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

type SSLLibCandidate struct {
	Path string
	Dev  uint64
	Ino  uint64
}

func HostRootCgroupID() uint64 {
	return 0
}

func KernelRelease() string {
	return runtime.GOOS + "/" + runtime.GOARCH
}

func ResolveContainerCgroup(_ int, _ string) (uint64, string) {
	return 0, ""
}

func ExtractContainerIDFromProcCgroup(_ uint32) (string, uint64) {
	return "", 0
}

func ReadProcDetails(
	pid uint32,
	containerCgroupID uint64,
	kernPPID uint32,
	kernComm string,
	kernParentComm string,
	kernCmdline string,
	history *PIDHistory,
) (uint32, string, string, []string) {
	if history != nil && pid > 0 {
		history.Record(pid, kernPPID, kernComm, kernCmdline, containerCgroupID)
	}
	var tree []string
	if kernParentComm != "" && kernPPID > 0 {
		tree = append(tree, formatProcessNode(kernPPID, kernParentComm, ""))
	}
	tree = append(tree, formatProcessNode(pid, kernComm, kernCmdline))
	return kernPPID, kernParentComm, kernCmdline, tree
}

func DiscoverSSLLibraries(_ []model.ContainerMeta) []SSLLibCandidate {
	return nil
}
