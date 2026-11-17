package classifier

import (
	"testing"

	"aexus.colosseum/pit-ebpf-sensor/internal/model"
)

func TestAllNineVFXClassifications(t *testing.T) {
	fighter := model.ContainerMeta{
		ContainerID: "f1",
		Name:        "pit-fighter-strix",
		CgroupID:    10001,
		PrimaryIP:   "172.28.0.11",
		MatchID:     "m-grail",
		SeatID:      "seat-1",
		Role:        model.RoleFighter,
	}
	target := model.ContainerMeta{
		ContainerID: "t1",
		Name:        "pit-target-grail",
		CgroupID:    20002,
		PrimaryIP:   "172.28.0.50",
		MatchID:     "m-grail",
		TargetID:    "target-grail",
		SeatID:      "seat-defender",
		Role:        model.RoleTarget,
	}

	t.Run("1_SONAR_SWEEP_nmap_and_nc_z", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventExecve,
				CgroupID:  fighter.CgroupID,
				PID:       501,
				Comm:      "nmap",
				Filename:  "/usr/bin/nmap",
			},
			SourceContainer:  fighter,
			InferredTargetID: target.TargetID,
			InferredDstIP:    target.PrimaryIP,
			Cmdline:          "/usr/bin/nmap -sV 172.28.0.50",
		})
		if !ok || ev.VFXType != model.VFXSonarSweep || ev.SourceSeatID != "seat-1" || ev.TargetID != "target-grail" {
			t.Fatalf("unexpected SONAR_SWEEP result: ok=%v ev=%+v", ok, ev)
		}

		evNc, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventExecve,
				CgroupID:  fighter.CgroupID,
				PID:       502,
				Comm:      "nc",
				Filename:  "/usr/bin/nc",
			},
			SourceContainer: fighter,
			Cmdline:         "nc -zv 172.28.0.50 8080",
		})
		if !ok || evNc.VFXType != model.VFXSonarSweep {
			t.Fatalf("expected nc -zv to classify as SONAR_SWEEP, got ok=%v %+v", ok, evNc)
		}
	})

	t.Run("2_ARMOR_PIERCING_BARRAGE_sqlmap_and_ffuf", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventExecve,
				CgroupID:  fighter.CgroupID,
				PID:       601,
				Comm:      "sqlmap",
				Filename:  "/usr/bin/sqlmap",
			},
			SourceContainer:  fighter,
			InferredTargetID: target.TargetID,
			Cmdline:          "sqlmap -u http://172.28.0.50:8080/item?id=1 --batch",
		})
		if !ok || ev.VFXType != model.VFXArmorPiercingBarrage || ev.OrganLayer != model.OrganDBVault {
			t.Fatalf("unexpected ARMOR_PIERCING_BARRAGE result: ok=%v ev=%+v", ok, ev)
		}
	})

	t.Run("3_PRECISION_EXPLOIT_BEAM_curl_and_connect", func(t *testing.T) {
		evExec, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventExecve,
				CgroupID:  fighter.CgroupID,
				PID:       701,
				Comm:      "curl",
				Filename:  "/usr/bin/curl",
			},
			SourceContainer:  fighter,
			InferredTargetID: target.TargetID,
			Cmdline:          "curl -X POST http://172.28.0.50:8080/api/render",
		})
		if !ok || evExec.VFXType != model.VFXPrecisionExploitBeam {
			t.Fatalf("unexpected curl PRECISION_EXPLOIT_BEAM: ok=%v ev=%+v", ok, evExec)
		}

		evConn, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventConnect,
				CgroupID:  fighter.CgroupID,
				PID:       701,
				Comm:      "python3",
				DstIP:     target.PrimaryIP,
				DstPort:   8080,
			},
			SourceContainer: fighter,
			DstContainer:    &target,
		})
		if !ok || evConn.VFXType != model.VFXPrecisionExploitBeam || evConn.TargetID != "target-grail" {
			t.Fatalf("unexpected connect PRECISION_EXPLOIT_BEAM: ok=%v ev=%+v", ok, evConn)
		}
	})

	t.Run("4_RCE_PARASITE_BREACH_python_spawns_sh", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventExecve,
				CgroupID:  target.CgroupID,
				PID:       4182,
				UID:       33,
				Comm:      "sh",
				Filename:  "/bin/sh",
			},
			SourceContainer:      target,
			RecentAttackerSeatID: "seat-1",
			PPID:                 3910,
			ParentComm:           "python3",
			Cmdline:              "/bin/sh -c id",
			ProcessTree:          []string{"python3 /app/app.py (PID 3910)", "/bin/sh -c id (PID 4182)"},
		})
		if !ok || ev.VFXType != model.VFXRCEParasiteBreach || ev.SourceSeatID != "seat-1" || ev.HitLocation != "/app/app.py" {
			t.Fatalf("unexpected RCE_PARASITE_BREACH: ok=%v ev=%+v", ok, ev)
		}
	})

	t.Run("5_REVERSE_SHELL_CHAIN_target_connects_to_fighter", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventConnect,
				CgroupID:  target.CgroupID,
				PID:       4200,
				Comm:      "bash",
				DstIP:     fighter.PrimaryIP,
				DstPort:   4444,
			},
			SourceContainer: target,
			DstContainer:    &fighter,
		})
		if !ok || ev.VFXType != model.VFXReverseShellChain || ev.SourceSeatID != "seat-1" || ev.TargetID != "target-grail" {
			t.Fatalf("unexpected REVERSE_SHELL_CHAIN: ok=%v ev=%+v", ok, ev)
		}
	})

	t.Run("6_GRAIL_HEART_STOLEN_openat_flag", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventOpenat,
				CgroupID:  target.CgroupID,
				PID:       4210,
				UID:       33,
				Comm:      "cat",
				Filename:  "/flag",
				Flags:     model.O_RDONLY,
			},
			SourceContainer:      target,
			RecentAttackerSeatID: "seat-1",
		})
		if !ok || ev.VFXType != model.VFXGrailHeartStolen || ev.OrganLayer != model.OrganFlagHeart {
			t.Fatalf("unexpected GRAIL_HEART_STOLEN: ok=%v ev=%+v", ok, ev)
		}
	})

	t.Run("7_NANO_PATCH_WELD_write_app_py_and_git_commit", func(t *testing.T) {
		// Read-only open of /app/app.py must NOT trigger NANO_PATCH_WELD
		if _, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventOpenat,
				CgroupID:  target.CgroupID,
				PID:       12,
				Comm:      "python3",
				Filename:  "/app/app.py",
				Flags:     model.O_RDONLY,
			},
			SourceContainer: target,
		}); ok {
			t.Fatal("O_RDONLY on /app/app.py must not trigger NANO_PATCH_WELD")
		}

		// Write open of /app/app.py MUST trigger NANO_PATCH_WELD
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventOpenat,
				CgroupID:  target.CgroupID,
				PID:       4300,
				Comm:      "python3",
				Filename:  "/app/app.py",
				Flags:     model.O_WRONLY | model.O_CREAT | model.O_TRUNC,
			},
			SourceContainer: target,
		})
		if !ok || ev.VFXType != model.VFXNanoPatchWeld || ev.SourceSeatID != "seat-defender" {
			t.Fatalf("unexpected NANO_PATCH_WELD: ok=%v ev=%+v", ok, ev)
		}
	})

	t.Run("8_ROOT_SHOCKWAVE_setuid_zero", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType: model.RawEventPrivesc,
				SubType:   model.PrivescSetuid,
				CgroupID:  target.CgroupID,
				PID:       4400,
				UID:       33,
				TargetUID: 0,
				Comm:      "pwn",
			},
			SourceContainer: target,
		})
		if !ok || ev.VFXType != model.VFXRootShockwave || ev.OrganLayer != model.OrganFlagHeart {
			t.Fatalf("unexpected ROOT_SHOCKWAVE: ok=%v ev=%+v", ok, ev)
		}
	})

	t.Run("9_SSL_CLEARTEXT_INTERCEPT_uprobe_SSL_write", func(t *testing.T) {
		ev, ok := Classify(Input{
			Raw: model.RawKernelEvent{
				EventType:  model.RawEventSSLWrite,
				CgroupID:   fighter.CgroupID,
				PID:        4500,
				Comm:       "curl",
				PayloadLen: 54,
				Payload:    []byte("POST /api/chat HTTP/1.1\r\nHost: grail.local\r\n\r\nAEXUS{1}"),
			},
			SourceContainer: fighter,
		})
		if !ok || ev.VFXType != model.VFXSSLCleartextIntercept || ev.CleartextPayload == "" {
			t.Fatalf("unexpected SSL_CLEARTEXT_INTERCEPT: ok=%v ev=%+v", ok, ev)
		}
	})
}
