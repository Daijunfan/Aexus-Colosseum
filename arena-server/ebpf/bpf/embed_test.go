package bpf

import (
	"bytes"
	"debug/elf"
	"testing"
)

func TestEmbeddedProbesELFValid(t *testing.T) {
	if len(ProbesELF) < 1024 {
		t.Fatalf("expected embedded probes_bpfel.o to be non-trivial, got %d bytes", len(ProbesELF))
	}

	f, err := elf.NewFile(bytes.NewReader(ProbesELF))
	if err != nil {
		t.Fatalf("failed to parse embedded ELF: %v", err)
	}
	defer f.Close()

	if f.Class != elf.ELFCLASS64 {
		t.Fatalf("expected ELFCLASS64, got %v", f.Class)
	}
	if f.Data != elf.ELFDATA2LSB {
		t.Fatalf("expected little-endian ELFDATA2LSB, got %v", f.Data)
	}
	if f.Machine != elf.EM_BPF {
		t.Fatalf("expected EM_BPF, got %v", f.Machine)
	}

	requiredSections := []string{
		".maps",
		".BTF",
		"license",
		"tracepoint/syscalls/sys_enter_execve",
		"tracepoint/syscalls/sys_exit_execve",
		"tracepoint/syscalls/sys_enter_connect",
		"tracepoint/syscalls/sys_enter_openat",
		"tracepoint/syscalls/sys_enter_setuid",
		"tracepoint/syscalls/sys_enter_setresuid",
		"kprobe/commit_creds",
		"uprobe/SSL_write",
		"uprobe/SSL_write_ex",
		"uprobe/SSL_read",
		"uretprobe/SSL_read",
		"uprobe/SSL_read_ex",
		"uretprobe/SSL_read_ex",
	}

	for _, sec := range requiredSections {
		if f.Section(sec) == nil {
			t.Errorf("missing required eBPF ELF section %q", sec)
		}
	}

	syms, err := f.Symbols()
	if err != nil {
		t.Fatalf("failed to read ELF symbols: %v", err)
	}
	foundPerfMap := false
	for _, s := range syms {
		if s.Name == "pit_perf_stats" {
			foundPerfMap = true
			break
		}
	}
	if !foundPerfMap {
		t.Errorf("expected compiled BPF ELF to define zero-lock per-CPU map symbol pit_perf_stats")
	}
}
