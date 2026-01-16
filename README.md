# Victim Cache Design: Complete RTL-to-GDSII Flow

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![FPGA](https://img.shields.io/badge/Platform-FPGA-orange.svg)](https://www.xilinx.com/)

## 📋 Project Overview

A comprehensive implementation of a **fully associative victim cache** integrated with an L1 direct-mapped cache, demonstrating the complete **RTL-to-GDSII** ASIC design flow. This project showcases advanced digital design, verification, and physical implementation skills essential for modern chip design.

### 🎯 Key Features

- ✅ **Fully Associative Victim Cache** - Reduces conflict misses in L1 cache
- ✅ **Complete RTL Implementation** - FSM-based control logic with modular design
- ✅ **L1 Cache Integration** - Seamless integration with direct-mapped L1 cache
- ✅ **Physical Design Flow** - RTL → Synthesis → Place & Route → GDSII
- ✅ **Comprehensive Verification** - Testbench with DRC/LVS verification
- ✅ **Performance Analysis** - Measurable improvement in miss rate reduction

---

## 🏗️ Architecture

### System Architecture

```
┌─────────────────────────────────────────────┐
│            CPU Core                         │
└──────────────┬──────────────────────────────┘
               │
       ┌───────▼────────┐
       │   L1 Cache     │ (Direct-Mapped)
       │  (Tag + Data)  │
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │ Victim Cache   │ (Fully Associative)
       │                │
       │  ┌──────────┐  │
       │  │Tag Store │  │
       │  └──────────┘  │
       │  ┌──────────┐  │
       │  │Data Store│  │
       │  └──────────┘  │
       │  ┌──────────┐  │
       │  │Replace   │  │
       │  │Logic     │  │
       │  └──────────┘  │
       └───────┬────────┘
               │
       ┌───────▼────────┐
       │   Main Memory  │
       └────────────────┘
```

### Victim Cache Components

1. **Tag Store Module** - Stores cache line tags with validity bits
2. **Data Store Module** - Holds evicted cache line data
3. **Replacement Logic** - Implements FIFO replacement policy
4. **FSM Controller** - Manages cache operations and state transitions
5. **Lookup Logic** - Parallel associative search across all entries

---

## 🔧 Technical Specifications

| Parameter | Value |
|-----------|-------|
| Cache Type | Fully Associative |
| Number of Entries | 4 (configurable) |
| Cache Line Size | 32 bytes |
| Data Width | 32 bits |
| Address Width | 32 bits |
| Replacement Policy | FIFO |
| Write Policy | Write-back |
| HDL | Verilog |
| Clock Frequency | 50 MHz (FPGA) |

---

## 📁 Project Structure

```
victim-cache/
├── rtl/
│   ├── victim_cache_top.v        # Top-level module
│   ├── victim_cache_fsm.v        # FSM controller
│   ├── tag_store.v               # Tag storage module
│   ├── data_store.v              # Data storage module
│   ├── replacement_logic.v       # FIFO replacement
│   ├── lookup_logic.v            # Associative search
│   └── l1_cache.v                # L1 cache integration
├── testbench/
│   ├── victim_cache_tb.v         # Main testbench
│   ├── test_scenarios.v          # Test case definitions
│   └── performance_eval.v        # Performance benchmarks
├── synthesis/
│   ├── scripts/                  # Synthesis scripts
│   ├── constraints/              # Timing constraints
│   └── reports/                  # Synthesis reports
├── physical_design/
│   ├── floorplan/               # Floorplanning files
│   ├── placement/               # Placement data
│   ├── routing/                 # Routing results
│   └── gdsii/                   # Final GDSII output
├── verification/
│   ├── drc_reports/             # DRC verification
│   ├── lvs_reports/             # LVS verification
│   └── timing_reports/          # Timing analysis
└── docs/
    ├── architecture.pdf         # Architecture documentation
    ├── design_spec.pdf          # Design specifications
    └── user_guide.pdf           # User guide
```

---

## 🚀 Getting Started

### Prerequisites

```bash
# Tools required
- Xilinx Vivado 2020.2 or later
- ModelSim or Xcelium for simulation
- Cadence Innovus for physical design
- Python 3.7+ (for scripts)
```

### Simulation

```bash
# Clone the repository
git clone https://github.com/anaskhan/victim-cache.git
cd victim-cache

# Run simulation
cd testbench
./run_simulation.sh

# View waveforms
gtkwave victim_cache_tb.vcd
```

### Synthesis

```bash
# Run synthesis flow
cd synthesis/scripts
./synthesize.tcl

# View synthesis reports
cat ../reports/timing_report.txt
cat ../reports/area_report.txt
```

### Physical Design

```bash
# Run place & route
cd physical_design
./run_pnr.sh

# Generate GDSII
./generate_gdsii.sh
```

---

## 📊 Performance Results

### Miss Rate Comparison

| Configuration | L1 Miss Rate | Total Access Time |
|--------------|--------------|-------------------|
| L1 Only      | 15.2%        | 1.82 ns           |
| L1 + Victim  | 8.7%         | 1.65 ns           |
| **Improvement** | **42.8% ↓** | **9.3% ↓**      |

### Timing Analysis

| Parameter | Value |
|-----------|-------|
| Setup Time (WNS) | 0.15 ns (MET) |
| Hold Time (WNS) | 0.08 ns (MET) |
| Max Frequency | 55.2 MHz |
| Clock Period | 18.1 ns |

### Area Report

| Component | Gates | Area (μm²) |
|-----------|-------|-----------|
| Tag Store | 428 | 1,245 |
| Data Store | 1,024 | 3,890 |
| FSM Control | 156 | 482 |
| Replacement Logic | 89 | 267 |
| **Total** | **1,697** | **5,884** |

---

## 🎓 Key Learning Outcomes

### Technical Skills Developed

1. **RTL Design**
   - Complex FSM design and implementation
   - Modular hierarchical design approach
   - Timing-aware design practices

2. **Verification**
   - Comprehensive testbench development
   - Corner case identification and testing
   - Performance benchmarking methodology

3. **Physical Design**
   - Synthesis optimization techniques
   - Floorplanning and placement strategies
   - Timing closure methodologies
   - DRC/LVS verification processes

4. **Problem Solving**
   - Resolved critical timing issues in sequential logic
   - Optimized data synchronization between modules
   - Debugged complex state machine interactions

---

## 🐛 Challenges & Solutions

### Challenge 1: Write Timing Issue
**Problem:** Tag store write operations required 2 clock cycles, causing data loss.

**Solution:** Modified internal evict registers to use combinational logic instead of sequential, ensuring single-cycle write completion.

### Challenge 2: Data Synchronization
**Problem:** Valid bit updated 2 clocks before actual data write, causing incorrect cache hits.

**Solution:** Redesigned write pipeline to synchronize valid bit and data updates on the same clock edge.

### Challenge 3: Timing Closure
**Problem:** Critical paths violated setup time constraints after integration.

**Solution:** 
- Added pipeline registers in critical paths
- Optimized logic depth in lookup logic
- Applied timing-driven synthesis constraints

---

## 📚 Documentation

- [Architecture Design Document](docs/architecture.pdf)
- [Verification Plan](docs/verification_plan.pdf)
- [Physical Design Flow](docs/physical_design.pdf)
- [User Guide](docs/user_guide.pdf)

---

## 🤝 Team & Contributions

- **M. Moiz Rafiq** (Team Lead) - FSM design, integration
- **Muhammad Uzair** - Data store implementation
- **Anas Khan** - Tag store, replacement logic, physical design

**Supervised by:** Miss Umm E Ammara

---

## 📈 Future Enhancements

- [ ] Implement LRU replacement policy option
- [ ] Add multi-level victim cache support
- [ ] Optimize for lower power consumption
- [ ] Add SystemVerilog assertions for verification
- [ ] Implement formal verification
- [ ] Add support for write-through policy

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📧 Contact

**Anas Khan**
- Email: anaskhan.seecs@gmail.com
- LinkedIn: [linkedin.com/in/anasee](https://www.linkedin.com/in/anasee)
- GitHub: [@anaskhan](https://github.com/anaskhan)

---

## 🌟 Acknowledgments

- NUST School of Electrical Engineering & Computer Science
- Miss Umm E Ammara for project supervision
- NUST Chip Design Centre for resources and guidance

---

<div align="center">

**⭐ If you found this project helpful, please give it a star!**

Made with ❤️ by [Anas Khan](https://github.com/anaskhan)

</div>
