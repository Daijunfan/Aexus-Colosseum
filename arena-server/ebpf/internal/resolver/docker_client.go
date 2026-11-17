package resolver

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os/exec"
	"strings"
	"time"
)

// RawDockerContainer represents inspected container details from Docker Engine API or CLI.
type RawDockerContainer struct {
	ID      string
	Name    string
	Image   string
	InitPID int
	Labels  map[string]string
	IPs     []string
}

type dockerListEntry struct {
	ID     string            `json:"Id"`
	Names  []string          `json:"Names"`
	Image  string            `json:"Image"`
	Labels map[string]string `json:"Labels"`
}

type dockerInspectResponse struct {
	ID     string `json:"Id"`
	Name   string `json:"Name"`
	State  struct {
		Pid     int  `json:"Pid"`
		Running bool `json:"Running"`
	} `json:"State"`
	Config struct {
		Image  string            `json:"Image"`
		Labels map[string]string `json:"Labels"`
	} `json:"Config"`
	NetworkSettings struct {
		IPAddress string `json:"IPAddress"`
		Networks  map[string]struct {
			IPAddress string `json:"IPAddress"`
		} `json:"Networks"`
	} `json:"NetworkSettings"`
}

// DockerClient queries container metadata via /var/run/docker.sock with CLI fallback.
type DockerClient struct {
	socketPath string
	httpClient *http.Client
}

func NewDockerClient(socketPath string) *DockerClient {
	if socketPath == "" {
		socketPath = "/var/run/docker.sock"
	}
	transport := &http.Transport{
		DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
			var d net.Dialer
			return d.DialContext(ctx, "unix", socketPath)
		},
		MaxIdleConns:        4,
		MaxIdleConnsPerHost: 4,
		IdleConnTimeout:     30 * time.Second,
	}
	return &DockerClient{
		socketPath: socketPath,
		httpClient: &http.Client{
			Transport: transport,
			Timeout:   2 * time.Second,
		},
	}
}

func (c *DockerClient) ListRunning(ctx context.Context) ([]RawDockerContainer, error) {
	containers, err := c.listViaSocket(ctx)
	if err == nil {
		return containers, nil
	}
	return c.listViaCLI(ctx)
}

func (c *DockerClient) InspectOne(ctx context.Context, idOrName string) (*RawDockerContainer, error) {
	rc, err := c.inspectViaSocket(ctx, idOrName)
	if err == nil {
		return rc, nil
	}
	return c.inspectViaCLI(ctx, idOrName)
}

func (c *DockerClient) listViaSocket(ctx context.Context) ([]RawDockerContainer, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, "http://docker/containers/json", nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("docker socket status %d", resp.StatusCode)
	}

	var entries []dockerListEntry
	if err := json.NewDecoder(resp.Body).Decode(&entries); err != nil {
		return nil, err
	}

	out := make([]RawDockerContainer, 0, len(entries))
	for _, entry := range entries {
		rc, err := c.inspectViaSocket(ctx, entry.ID)
		if err != nil || rc == nil {
			continue
		}
		out = append(out, *rc)
	}
	return out, nil
}

func (c *DockerClient) inspectViaSocket(ctx context.Context, id string) (*RawDockerContainer, error) {
	u := "http://docker/containers/" + url.PathEscape(id) + "/json"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, err
	}
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("docker inspect %s status %d", id, resp.StatusCode)
	}

	var ins dockerInspectResponse
	if err := json.NewDecoder(resp.Body).Decode(&ins); err != nil {
		return nil, err
	}
	return convertInspect(ins), nil
}

func (c *DockerClient) listViaCLI(ctx context.Context) ([]RawDockerContainer, error) {
	cmd := exec.CommandContext(ctx, "docker", "ps", "-q", "--no-trunc")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	ids := strings.Fields(string(out))
	if len(ids) == 0 {
		return nil, nil
	}

	args := append([]string{"inspect"}, ids...)
	insOut, err := exec.CommandContext(ctx, "docker", args...).Output()
	if err != nil {
		return nil, err
	}
	var list []dockerInspectResponse
	if err := json.Unmarshal(insOut, &list); err != nil {
		return nil, err
	}
	res := make([]RawDockerContainer, 0, len(list))
	for _, ins := range list {
		if rc := convertInspect(ins); rc != nil {
			res = append(res, *rc)
		}
	}
	return res, nil
}

func (c *DockerClient) inspectViaCLI(ctx context.Context, id string) (*RawDockerContainer, error) {
	insOut, err := exec.CommandContext(ctx, "docker", "inspect", id).Output()
	if err != nil {
		return nil, err
	}
	var list []dockerInspectResponse
	if err := json.Unmarshal(insOut, &list); err != nil || len(list) == 0 {
		return nil, fmt.Errorf("empty docker inspect for %s", id)
	}
	return convertInspect(list[0]), nil
}

func convertInspect(ins dockerInspectResponse) *RawDockerContainer {
	if !ins.State.Running && ins.State.Pid <= 0 {
		return nil
	}
	seenIP := map[string]bool{}
	var ips []string
	addIP := func(ip string) {
		ip = strings.TrimSpace(ip)
		if ip != "" && !seenIP[ip] {
			seenIP[ip] = true
			ips = append(ips, ip)
		}
	}
	for _, netCfg := range ins.NetworkSettings.Networks {
		addIP(netCfg.IPAddress)
	}
	addIP(ins.NetworkSettings.IPAddress)

	labels := ins.Config.Labels
	if labels == nil {
		labels = map[string]string{}
	}
	return &RawDockerContainer{
		ID:      ins.ID,
		Name:    strings.TrimPrefix(ins.Name, "/"),
		Image:   ins.Config.Image,
		InitPID: ins.State.Pid,
		Labels:  labels,
		IPs:     ips,
	}
}

// WatchContainerEvents streams Docker container lifecycle notifications and calls onChange.
func (c *DockerClient) WatchContainerEvents(ctx context.Context, onChange func()) {
	streamClient := &http.Client{
		Transport: c.httpClient.Transport,
		Timeout:   0, // streaming connection
	}
	filters := url.QueryEscape(`{"type":["container"],"event":["start","die","stop","destroy","restart"]}`)
	u := "http://docker/events?filters=" + filters

	for {
		if ctx.Err() != nil {
			return
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
		if err != nil {
			return
		}
		resp, err := streamClient.Do(req)
		if err != nil {
			select {
			case <-ctx.Done():
				return
			case <-time.After(2 * time.Second):
				continue
			}
		}

		scanner := bufio.NewScanner(resp.Body)
		for scanner.Scan() {
			if ctx.Err() != nil {
				resp.Body.Close()
				return
			}
			onChange()
		}
		resp.Body.Close()

		select {
		case <-ctx.Done():
			return
		case <-time.After(time.Second):
		}
	}
}
