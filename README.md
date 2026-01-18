# Victim Cache Implementation: RTL to GDSII

<div align="center">

![Victim Cache](https://img.shields.io/badge/Cache-Victim_Cache-blue)
![RTL](https://img.shields.io/badge/Design-RTL_to_GDSII-green)
![Verilog](https://img.shields.io/badge/Language-Verilog-orange)
![License](https://img.shields.io/badge/License-MIT-yellow)

**A complete hardware implementation of a Victim Cache from RTL design to GDSII layout**

</div>

---

## 📋 Table of Contents

- [Introduction](#introduction)
- [Team Members](#team-members)
- [Features](#features)
- [Architecture](#architecture)
- [Implementation Details](#implementation-details)
- [Simulation Results](#simulation-results)
- [Performance Evaluation](#performance-evaluation)
- [Tools & Technologies](#tools--technologies)
- [Getting Started](#getting-started)
- [Project Timeline](#project-timeline)
- [Challenges & Solutions](#challenges--solutions)
- [Future Work](#future-work)
- [References](#references)
- [License](#license)

---

## 🎯 Introduction

This project presents a complete **Victim Cache** design implemented from RTL (Register Transfer Level) to GDSII physical layout. A victim cache is a small, fully associative buffer placed next to the L1 cache that holds recently evicted cache blocks, significantly reducing conflict misses and improving overall cache performance.

### What is a Victim Cache?

- A **small, fully associative buffer** placed next to L1 cache
- Holds a few **recently evicted L1 blocks** (victims)
- If L1 misses but victim cache hits, **data is returned quickly**
- **Reduces miss rate** with minimal hardware overhead
- Combines the benefits of **direct-mapped** and **fully associative** caches

### Why Victim Cache?

The victim cache bridges the gap between two cache architectures:

**Direct-Mapped Cache:**
- ✅ Low hit time
- ✅ Simple hardware
- ❌ Low hit ratio
- ❌ Prone to ping-pong effect

**Fully Associative Cache:**
- ✅ High hit ratio
- ❌ High hit time due to complex hardware

**Victim Cache Solution:**
- Combines advantages of both architectures
- Minimal hardware overhead
- Significant performance improvement

---

## 👥 Team Members

| Name | Role |
|------|------|
| **M. Moiz Rafiq** | Team Leader |
| **Muhammad Uzair** | Team Member |
| **Anas Khan** | Team Member |

**Supervisor:** Miss Umm E Ammara

**Institution:** NUST Pakistan

---

## ✨ Features

- ✅ **Fully Associative Architecture** - Any block can be placed in any line
- ✅ **Tag Store Module** - Efficient tag comparison and lookup
- ✅ **Data Store Module** - Organized data storage and retrieval
- ✅ **LRU Replacement Policy** - Least Recently Used algorithm implementation
- ✅ **Control FSM** - Finite State Machine for cache operations
- ✅ **L1 Cache Integration** - Seamless integration with L1 direct-mapped cache
- ✅ **Complete RTL to GDSII Flow** - Full front-end and back-end design
- ✅ **Synthesizable Design** - Ready for FPGA/ASIC implementation
- ✅ **Comprehensive Testbenches** - Thorough verification environment
- ✅ **Timing Analysis** - Setup and hold time verification
- ✅ **DRC/LVS Clean** - Physical verification passed

---

## 🏗️ Architecture

### System Block Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Main Memory                           │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
         ┌─────────────────────────────┐
         │      L1 Direct-Mapped       │
         │          Cache              │
         └──────┬──────────────┬───────┘
                │              │
                │ Miss         │ Evicted Block
                ▼              ▼
         ┌─────────────────────────────┐
         │      Victim Cache           │
         │   (Fully Associative)       │
         │                             │
         │  ┌──────────┬──────────┐   │
         │  │Tag Store │Data Store│   │
         │  └──────────┴──────────┘   │
         │  ┌──────────────────────┐  │
         │  │  Replacement Logic   │  │
         │  │       (LRU)          │  │
         │  └──────────────────────┘  │
         │  ┌──────────────────────┐  │
         │  │    Control FSM       │  │
         │  └──────────────────────┘  │
         └─────────────────────────────┘
```

### Victim Cache Internal Architecture

![Victim Cache Block Diagram](docs/images/victim_cache_block_diagram.png)
*Caption: Internal block diagram of the Victim Cache showing all submodules*

<!-- PLACEHOLDER: Add your block diagram image in docs/images/ directory -->

### Finite State Machine (FSM)

![FSM Diagram](docs/images/fsm_diagram.png)
*Caption: Control FSM showing all states and transitions*

<!-- PLACEHOLDER: Add your FSM diagram image in docs/images/ directory -->

### Replacement Policy Flowchart

![Replacement Policy](docs/images/replacement_policy_flowchart.png)
*Caption: LRU replacement policy decision flowchart*

<!-- PLACEHOLDER: Add your replacement policy flowchart in docs/images/ directory -->

---

## 🔧 Implementation Details

### Submodules

#### 1. **Tag Store Module**

**Purpose:** Stores and compares cache line tags for lookup operations

**Features:**
- Fully associative tag comparison
- Parallel tag matching
- Valid bit management
- Write and read operations

**Block Diagram:**

```
┌─────────────────────────────────┐
│       Tag Store Module          │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │   Lookup Logic            │ │
│  │   - Parallel Comparison   │ │
│  │   - Hit/Miss Detection    │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   Write Logic             │ │
│  │   - Tag Write             │ │
│  │   - Valid Bit Update      │ │
│  └───────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐ │
│  │   Read Logic              │ │
│  │   - Tag Read              │ │
│  │   - Status Output         │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

#### 2. **Data Store Module**

**Purpose:** Stores cache line data and manages data access

**Features:**
- Data array management
- Read/write data operations
- Data eviction handling

#### 3. **Replacement Logic (LRU)**

**Purpose:** Implements Least Recently Used replacement algorithm

**Features:**
- LRU counter management
- Victim line selection
- Age update on access

#### 4. **Control FSM**

**Purpose:** Coordinates all cache operations

**States:**
- IDLE: Waiting for request
- LOOKUP: Searching for tag
- HIT: Data found, return to L1
- MISS: Data not found
- EVICT: Evict line to make space
- UPDATE: Update replacement policy

#### 5. **L1 Direct-Mapped Cache**

**Purpose:** Primary cache working with victim cache

**Features:**
- Direct-mapped organization
- Fast hit time
- Eviction to victim cache on conflict

---

## 📊 Simulation Results

### Tag Store Module Verification

![Tag Store Simulation](docs/images/tag_store_simulation.png)
*Caption: Waveform showing tag store read and write operations*

<!-- PLACEHOLDER: Add your tag store simulation waveform -->

**Test Cases Covered:**
- ✅ Tag write operations
- ✅ Tag lookup (hit/miss)
- ✅ Valid bit management
- ✅ Parallel tag comparison

### Full System Simulation

![Full System Simulation](docs/images/full_system_simulation.png)
*Caption: Complete victim cache operation with L1 cache integration*

<!-- PLACEHOLDER: Add your full system simulation waveform -->

**Verified Operations:**
- ✅ L1 miss → Victim cache lookup
- ✅ Victim cache hit → Data return
- ✅ Victim cache miss → Memory fetch
- ✅ Block eviction and replacement
- ✅ LRU policy updates

### Post-Synthesis Netlist

![Post-Synthesis Netlist](docs/images/post_synthesis_netlist.png)
*Caption: Synthesized netlist showing gate-level implementation*

<!-- PLACEHOLDER: Add your synthesis result screenshot -->

---

## 📈 Performance Evaluation

A pseudo-program consisting of read and write instructions was executed to compare performance:

### Test Setup
- **Configuration:** L1 cache with and without victim cache
- **Clock Period:** 5 ns
- **Test Program:** Mixed read/write operations with conflict patterns

### Results

![Performance Comparison](docs/images/performance_comparison.png)
*Caption: Performance comparison showing miss rate reduction*

<!-- PLACEHOLDER: Add your performance comparison graph/table -->

| Metric | L1 Only | L1 + Victim Cache | Improvement |
|--------|---------|-------------------|-------------|
| Hit Rate | XX% | XX% | +XX% |
| Miss Rate | XX% | XX% | -XX% |
| Average Access Time | XX ns | XX ns | -XX% |
| Conflict Misses | XXX | XXX | -XX% |

<!-- FILL IN: Add your actual performance numbers -->

### Key Findings

- 🎯 **Reduced Conflict Misses:** Victim cache effectively captures evicted blocks
- ⚡ **Improved Hit Rate:** Overall cache hit rate increased by XX%
- 🕒 **Minimal Latency Penalty:** Victim cache lookup adds negligible delay
- 💡 **Cost-Effective:** Significant performance gain with small hardware overhead

---

## 🔬 GDSII Implementation

### Timing Analysis

#### Setup Time Analysis

![Setup Time Analysis](docs/images/setup_time_analysis.png)
*Caption: Setup time analysis showing timing closure*

<!-- PLACEHOLDER: Add your setup time analysis screenshot -->

**Results:**
- ✅ All paths meet setup time requirements
- ✅ Critical path: XX ns
- ✅ Slack: +XX ns

#### Hold Time Analysis

![Hold Time Analysis](docs/images/hold_time_analysis.png)
*Caption: Hold time analysis results*

<!-- PLACEHOLDER: Add your hold time analysis screenshot -->

**Results:**
- ✅ All paths meet hold time requirements
- ✅ Minimum slack: +XX ns
- ✅ No hold violations

### Physical Verification

#### DRC (Design Rule Check)

![DRC Verification](docs/images/drc_verification.png)
*Caption: DRC verification results - CLEAN*

<!-- PLACEHOLDER: Add your DRC results screenshot -->

**Status:** ✅ **PASSED** - No DRC violations

#### LVS (Layout vs Schematic)

![LVS Verification](docs/images/lvs_verification.png)
*Caption: Connectivity verification results - CLEAN*

<!-- PLACEHOLDER: Add your LVS results screenshot -->

**Status:** ✅ **PASSED** - Layout matches schematic

### Final GDSII Layout

![GDSII Layout](docs/images/gdsii_layout.png)
*Caption: Final GDSII layout of victim cache*

<!-- PLACEHOLDER: Add your GDSII layout view -->

**Chip Statistics:**
- **Area:** XX µm²
- **Power:** XX mW
- **Operating Frequency:** XX MHz
- **Technology Node:** XX nm

---

## 🛠️ Tools & Technologies

### Hardware Description Language
- **Verilog/SystemVerilog** - RTL design and testbenches

### Simulation & Verification
- **Xilinx Vivado** - Synthesis and simulation
- **ModelSim/QuestaSim** - Advanced simulation (if used)
- **Waveform Viewers** - Signal analysis

### Synthesis & Implementation
- **Xilinx Vivado** - Logic synthesis
- **Synopsys Design Compiler** - Synthesis (if used)

### Physical Design
- **Cadence Innovus** - Place and route
- **Synopsys IC Compiler** - Physical implementation (if used)

### Verification
- **Calibre** - DRC/LVS verification
- **Mentor Graphics** - Physical verification

### Version Control
- **Git/GitHub** - Source code management

---

## 🚀 Getting Started

### Prerequisites

- Xilinx Vivado (2020.x or later)
- ModelSim/QuestaSim (optional)
- Git

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/Anaskhan198/Victim-Cache-Implementation-RTL-to-GDSII.git
cd Victim-Cache-Implementation-RTL-to-GDSII
```

2. **Set up your environment:**
```bash
# Source Vivado settings (adjust path as needed)
source /path/to/Vivado/2020.x/settings64.sh
```

### Running Simulations

#### Option 1: Using Vivado GUI

1. Open Vivado
2. Create new project or open existing
3. Add source files from `rtl/` directory
4. Add testbench files from `tb/` directory
5. Run simulation

#### Option 2: Using Command Line

```bash
# Compile RTL files
vlog rtl/*.v

# Compile testbench
vlog tb/tb_victim_cache.v

# Run simulation
vsim -c tb_victim_cache -do "run -all; quit"

# View waveform
vsim tb_victim_cache
```

### Synthesis

```bash
# Open Vivado in batch mode
vivado -mode batch -source scripts/synthesize.tcl
```

### Testing Individual Modules

```bash
# Test tag store module
cd tb/
vivado -mode batch -source run_tag_store_tb.tcl

# Test data store module
vivado -mode batch -source run_data_store_tb.tcl

# Test full victim cache
vivado -mode batch -source run_victim_cache_tb.tcl
```

---

## 📁 Project Structure

```
Victim-Cache-Implementation-RTL-to-GDSII/
│
├── rtl/                          # RTL source files
│   ├── victim_cache.v           # Top-level victim cache module
│   ├── tag_store.v              # Tag store module
│   ├── data_store.v             # Data store module
│   ├── replacement_logic.v      # LRU replacement logic
│   ├── control_fsm.v            # Control finite state machine
│   └── l1_cache.v               # L1 direct-mapped cache
│
├── tb/                           # Testbench files
│   ├── tb_victim_cache.v        # Main testbench
│   ├── tb_tag_store.v           # Tag store testbench
│   ├── tb_data_store.v          # Data store testbench
│   └── test_vectors/            # Test input files
│
├── constraints/                  # Timing and physical constraints
│   ├── timing.xdc               # Timing constraints
│   └── physical.xdc             # Physical constraints
│
├── scripts/                      # Automation scripts
│   ├── synthesize.tcl           # Synthesis script
│   ├── simulate.tcl             # Simulation script
│   └── run_all.sh               # Run complete flow
│
├── docs/                         # Documentation
│   ├── images/                  # Images and diagrams
│   ├── specifications.pdf       # Design specifications
│   └── user_guide.md            # User guide
│
├── synthesis/                    # Synthesis outputs
│   └── reports/                 # Synthesis reports
│
├── simulation/                   # Simulation results
│   └── waveforms/               # Waveform dumps
│
├── presentations/                # Project presentations
│   ├── Presentation_victim_cache__1___3_.pptx
│   └── Project_presentation_final.pptx
│
├── README.md                     # This file
├── LICENSE                       # MIT License
└── .gitignore                   # Git ignore file
```

---

## 📅 Project Timeline

| Phase | Tasks | Duration | Status |
|-------|-------|----------|--------|
| **Phase 1: Requirements & Planning** | Project scope definition, Literature review | Week 1-2 | ✅ Complete |
| **Phase 2: RTL Design** | Tag store, Data store, Replacement logic | Week 3-5 | ✅ Complete |
| **Phase 3: L1 Cache Integration** | L1 cache design, Integration with victim cache | Week 6-7 | ✅ Complete |
| **Phase 4: Control FSM** | FSM design, Submodule integration | Week 8 | ✅ Complete |
| **Phase 5: Verification** | Testbench development, Simulation | Week 9-10 | ✅ Complete |
| **Phase 6: Synthesis** | Logic synthesis, Timing analysis | Week 11 | ✅ Complete |
| **Phase 7: Physical Design** | Place and route, GDSII generation | Week 12-13 | ✅ Complete |
| **Phase 8: Verification** | DRC, LVS, Timing verification | Week 14 | ✅ Complete |
| **Phase 9: Documentation** | Final report, Presentations | Week 15 | ✅ Complete |

**Project Start Date:** October 2025  
**Project Completion Date:** December 17, 2025

---

## 🚧 Challenges & Solutions

### Challenge 1: Tag Store Write Timing Issue

**Problem:**  
During initial simulation in Xilinx Vivado, the write operation was not performed correctly. The last write required 2 clock cycles, otherwise the data was missed.

**Root Cause:**  
After synthesis and close inspection, it was discovered that the issue was in the testbench, not the RTL design.

**Solution:**  
- Corrected the testbench timing
- Verified proper write operation
- ✅ Issue resolved

---

### Challenge 2: Critical Timing Issues with L1 Integration

**Problem:**  
After connecting the victim cache with the L1 direct-mapped cache, critical timing issues occurred. The victim cache was getting hits but fetching incorrect data.

**Root Cause:**  
The internal victim cache evict registers were accepting data on a clock edge, and then another clock edge was required to write the data. However, the valid bit was written 2 clocks prior to the data, causing synchronization issues.

**Solution:**  
- Changed internal evict registers from sequential to combinational logic
- Ensured valid bit and data are written synchronously
- ✅ Timing issues resolved, correct data fetching achieved

---

### Challenge 3: Physical Design Timing Closure

**Problem:**  
Initial physical design had setup time violations on critical paths.

**Solution:**  
- Optimized critical path logic
- Applied proper timing constraints
- Used pipelining where beneficial
- ✅ Achieved timing closure with positive slack

---

## 🔮 Future Work

- [ ] **Multi-level Victim Cache:** Implement hierarchical victim cache levels
- [ ] **Adaptive Replacement Policies:** Add support for multiple replacement algorithms (FIFO, Random)
- [ ] **Configurable Parameters:** Make cache size and associativity parameterizable
- [ ] **Power Optimization:** Implement clock gating and power-aware design
- [ ] **Cache Coherence:** Add support for multi-core cache coherence protocols
- [ ] **Write Buffer:** Integrate write buffer for improved write performance
- [ ] **Prefetching:** Implement intelligent prefetching mechanism
- [ ] **FPGA Prototype:** Deploy on FPGA for real-world testing

---

## 📚 References

### Books
1. Hennessy, J. L., & Patterson, D. A. (2017). *Computer Architecture: A Quantitative Approach* (6th ed.). Morgan Kaufmann.
2. Harris, S. L., & Harris, D. (2015). *Digital Design and Computer Architecture* (2nd ed.). Morgan Kaufmann.

### Papers
1. Jouppi, N. P. (1990). "Improving direct-mapped cache performance by the addition of a small fully-associative cache and prefetch buffers." *ISCA '90: Proceedings of the 17th annual international symposium on Computer Architecture*.

### Online Resources
- [Computer Architecture Course - MIT OpenCourseWare](https://ocw.mit.edu/)
- [Vivado Design Suite User Guide](https://www.xilinx.com/support/documentation/)
- [Digital Design and Computer Architecture Resources](http://booksite.elsevier.com/9780123944245/)

### Tools Documentation
- [Xilinx Vivado Documentation](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2020_2/ug835-vivado-tcl-commands.pdf)
- [Verilog IEEE Standard](https://ieeexplore.ieee.org/document/954909)

---

## 👏 Acknowledgments

We would like to express our sincere gratitude to:

- **Miss Umm E Ammara** - Our supervisor, for her invaluable guidance and support throughout the project
- **NUST Pakistan** - For providing resources and facilities
- **Digital Design Lab** - For access to tools and equipment
- **Our Families** - For their continuous encouragement and support

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 M. Moiz Rafiq, Muhammad Uzair, Anas Khan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📞 Contact

**Project Team:**

- **M. Moiz Rafiq** (Team Leader)
  - Email: [email@example.com]
  - LinkedIn: [Your LinkedIn]
  - GitHub: [@username](https://github.com/username)

- **Muhammad Uzair**
  - Email: [email@example.com]
  - LinkedIn: [Your LinkedIn]

- **Anas Khan**
  - Email: [anaskhanbjr22@gmail.com]
  - LinkedIn: [Your LinkedIn]
  - GitHub: [@Anaskhan198](https://github.com/Anaskhan198)

**Project Repository:** [github.com/Anaskhan198/Victim-Cache-Implementation-RTL-to-GDSII](https://github.com/Anaskhan198/Victim-Cache-Implementation-RTL-to-GDSII)

---

## 🌟 Star History

If you find this project useful, please consider giving it a ⭐ on GitHub!

[![Star History Chart](https://api.star-history.com/svg?repos=Anaskhan198/Victim-Cache-Implementation-RTL-to-GDSII&type=Date)](https://star-history.com/#Anaskhan198/Victim-Cache-Implementation-RTL-to-GDSII&Date)

---

<div align="center">

**Made with ❤️ by the Victim Cache Team**

**NUST Pakistan | 2025**

[⬆ Back to Top](#victim-cache-implementation-rtl-to-gdsii)

</div>
