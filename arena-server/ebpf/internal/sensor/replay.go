package sensor

import (
	"context"
	"time"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

// RunReplayDemo registers synthetic match containers and emits a deterministic full-spectrum
// 9-stage attack/defense sequence so macOS / non-root developers can test the full pipeline.
func (e *Engine) RunReplayDemo(ctx context.Context, interval time.Duration, loop bool) error {
	if interval <= 0 {
		interval = 650 * time.Millisecond
	}

	fighter1 := model.ContainerMeta{
		ContainerID: "replay-fighter-strix-0001",
		ShortID:     "replay-figh1",
		Name:        "pit-fighter-strix",
		InitPID:     2101,
		CgroupID:    810001,
		PrimaryIP:   "172.28.0.11",
		IPs:         []string{"172.28.0.11"},
		MatchID:     "m-demo-grail",
		SeatID:      "seat-1",
		Role:        model.RoleFighter,
	}
	defender := model.ContainerMeta{
		ContainerID: "replay-target-grail-0050",
		ShortID:     "replay-targ1",
		Name:        "pit-target-grail",
		InitPID:     3901,
		CgroupID:    849201,
		PrimaryIP:   "172.28.0.50",
		IPs:         []string{"172.28.0.50"},
		MatchID:     "m-demo-grail",
		TargetID:    "target-grail",
		SeatID:      "seat-4",
		Role:        model.RoleTarget,
	}

	e.resolver.InjectContainerForTest(fighter1)
	e.resolver.InjectContainerForTest(defender)
	e.resolver.PIDHistory().Record(3901, 1, "gunicorn", "gunicorn -w 2 app:app", defender.CgroupID)
	e.resolver.PIDHistory().Record(3910, 3901, "python3", "python3 /app/app.py", defender.CgroupID)

	stages := []model.RawKernelEvent{
		{
			EventType: model.RawEventExecve,
			CgroupID:  fighter1.CgroupID,
			PID:       2201,
			PPID:      2101,
			UID:       0,
			Comm:      "nmap",
			Filename:  "/usr/bin/nmap",
			ArgCount:  4,
			Args:      []string{"nmap", "-sV", "-p80,443,8080", "172.28.0.50"},
		},
		{
			EventType: model.RawEventExecve,
			CgroupID:  fighter1.CgroupID,
			PID:       2215,
			PPID:      2101,
			UID:       0,
			Comm:      "ffuf",
			Filename:  "/usr/bin/ffuf",
			ArgCount:  4,
			Args:      []string{"ffuf", "-u", "http://172.28.0.50:8080/FUZZ", "-w"},
		},
		{
			EventType: model.RawEventSSLWrite,
			CgroupID:  fighter1.CgroupID,
			PID:       2230,
			PPID:      2101,
			UID:       0,
			Comm:      "curl",
			PayloadLen: 92,
			Payload:    []byte("POST /api/chat HTTP/1.1\r\nHost: 172.28.0.50:8443\r\n\r\n{\"prompt\":\"{{cycler.__init__.__globals__}}\"}"),
		},
		{
			EventType: model.RawEventConnect,
			CgroupID:  fighter1.CgroupID,
			PID:       2230,
			PPID:      2101,
			UID:       0,
			Comm:      "python3",
			DstIP:     defender.PrimaryIP,
			DstPort:   8080,
		},
		{
			EventType:  model.RawEventExecve,
			CgroupID:   defender.CgroupID,
			PID:        4182,
			PPID:       3910,
			UID:        33,
			Comm:       "sh",
			ParentComm: "python3",
			Filename:   "/bin/sh",
			ArgCount:   3,
			Args:       []string{"/bin/sh", "-c", "id && cat /flag"},
		},
		{
			EventType:  model.RawEventConnect,
			CgroupID:   defender.CgroupID,
			PID:        4190,
			PPID:       4182,
			UID:        33,
			Comm:       "bash",
			ParentComm: "sh",
			DstIP:      fighter1.PrimaryIP,
			DstPort:    4444,
		},
		{
			EventType:  model.RawEventOpenat,
			CgroupID:   defender.CgroupID,
			PID:        4195,
			PPID:       4182,
			UID:        33,
			Comm:       "cat",
			ParentComm: "sh",
			Filename:   "/flag",
			Flags:      model.O_RDONLY,
		},
		{
			EventType:  model.RawEventPrivesc,
			SubType:    model.PrivescCommitCred,
			CgroupID:   defender.CgroupID,
			PID:        4205,
			PPID:       4190,
			UID:        33,
			TargetUID:  0,
			Comm:       "suid-helper",
			ParentComm: "bash",
		},
		{
			EventType:  model.RawEventOpenat,
			CgroupID:   defender.CgroupID,
			PID:        4310,
			PPID:       3901,
			UID:        0,
			Comm:       "python3",
			ParentComm: "bash",
			Filename:   "/app/app.py",
			Flags:      model.O_WRONLY | model.O_CREAT | model.O_TRUNC,
		},
	}

	for {
		for _, raw := range stages {
			if ctx.Err() != nil {
				return nil
			}
			raw.TimestampNs = uint64(time.Now().UnixNano())
			e.ProcessRawEvent(raw)

			select {
			case <-ctx.Done():
				return nil
			case <-time.After(interval):
			}
		}
		if !loop {
			return nil
		}
	}
}
