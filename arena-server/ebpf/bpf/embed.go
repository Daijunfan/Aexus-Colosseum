package bpf

import _ "embed"

// ProbesELF contains the compiled 64-bit little-endian Linux eBPF ELF object
// with BTF CO-RE metadata (compiled from probes.bpf.c).
//
//go:embed probes_bpfel.o
var ProbesELF []byte
