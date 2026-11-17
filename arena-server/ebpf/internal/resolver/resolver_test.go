package resolver

import (
	"testing"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

func TestParseContainerIDFromCgroupText(t *testing.T) {
	id := "bc1eca115c85086bcb4ee46168f2ed66f1aa40fb2e322c569a1b01e2de95b778"
	cases := []struct {
		name string
		raw  string
		want string
	}{
		{
			name: "ubuntu22_cgroupv2_systemd_scope",
			raw:  "0::/system.slice/docker-" + id + ".scope\n",
			want: id,
		},
		{
			name: "cgroupfs_docker_path",
			raw:  "12:pids:/docker/" + id + "\n0::/docker/" + id + "\n",
			want: id,
		},
		{
			name: "host_sshd_process",
			raw:  "0::/system.slice/ssh.service\n",
			want: "",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, _ := ParseContainerIDFromCgroupText(tc.raw)
			if got != tc.want {
				t.Fatalf("got %q, want %q", got, tc.want)
			}
		})
	}
}

func TestBuildContainerMetaLabelsAndConventions(t *testing.T) {
	fighter, keep := BuildContainerMeta(RawDockerContainer{
		ID:      "1111111111112222222222223333333333334444444444445555555555556666",
		Name:    "/pit-verify-fighter",
		InitPID: 1001,
		IPs:     []string{"172.28.0.11"},
		Labels: map[string]string{
			"pit.match_id": "m-grail-01",
			"pit.seat_id":  "seat-1",
			"pit.role":     "fighter",
		},
	}, 9001, "/sys/fs/cgroup/system.slice/docker-111.scope", false)
	if !keep {
		t.Fatal("expected labeled fighter container to be kept")
	}
	if fighter.Role != model.RoleFighter || fighter.SeatID != "seat-1" || fighter.MatchID != "m-grail-01" || fighter.PrimaryIP != "172.28.0.11" {
		t.Fatalf("unexpected fighter meta: %+v", fighter)
	}

	// Name convention fallback without explicit pit.* labels
	convTarget, keep := BuildContainerMeta(RawDockerContainer{
		ID:   "abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
		Name: "/arena-vulhub-tomcat-1",
		IPs:  []string{"172.18.0.5"},
	}, 9002, "", false)
	if !keep || convTarget.Role != model.RoleTarget || convTarget.TargetID != "arena-vulhub-tomcat-1" {
		t.Fatalf("expected arena-* container to resolve as target: keep=%v meta=%+v", keep, convTarget)
	}

	// Unrelated container rejected when includeUnlabeled == false
	_, keep = BuildContainerMeta(RawDockerContainer{
		ID:   "9999999999999999999999999999999999999999999999999999999999999999",
		Name: "/portainer",
	}, 9003, "", false)
	if keep {
		t.Fatal("expected unrelated unlabeled container to be ignored")
	}
}
