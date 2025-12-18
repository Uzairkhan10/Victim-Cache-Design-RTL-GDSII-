`timescale 1ns/1ps

module top #(
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter LINE_BYTES       = 16,
    parameter CACHE_BYTES      = 256,
    parameter VICTIM_TAG_WIDTH = 27
)(
    input  logic clk,
    input  logic rst_n,

    // CPU interface
    input  logic                    cpu_req_valid,
    input  logic                    cpu_req_rw,
    input  logic [ADDR_WIDTH-1:0]   cpu_req_addr,
    input  logic [DATA_WIDTH-1:0]   cpu_req_wdata,

    output logic                    cpu_resp_valid,
    output logic [DATA_WIDTH-1:0]   cpu_resp_rdata,

    // Memory interface
    output logic                    mem_req_valid,
    output logic                    mem_req_rw,
    output logic [ADDR_WIDTH-1:0]   mem_req_addr,
    output logic [LINE_BYTES*8-1:0] mem_req_wdata,

    input  logic                    mem_resp_valid,
    input  logic [LINE_BYTES*8-1:0] mem_resp_rdata
);

    // =============================================================
    // Internal signals
    // =============================================================
    logic l1_mem_req_valid_i, l1_mem_req_rw_i;
    logic [ADDR_WIDTH-1:0] l1_mem_req_addr_i;
    logic [LINE_BYTES*8-1:0] l1_mem_req_wdata_i;

    logic vc_mem_req_i, vc_mem_req_write_i;
    logic [VICTIM_TAG_WIDTH-1:0] vc_mem_req_tag_i;
    logic [LINE_BYTES*8-1:0] vc_mem_req_wdata_i;
    logic vc_mem_resp_valid_i;

    // L1 ↔ VC interface
    logic vc_ready;
    logic vc_probe_valid, vc_probe_ready, vc_probe_hit, vc_probe_dirty;
    logic [LINE_BYTES*8-1:0] vc_probe_line;
    logic [VICTIM_TAG_WIDTH-1:0] vc_probe_tag;

    logic vc_evict_valid, vc_evict_ack, vc_evict_dirty;
    logic [LINE_BYTES*8-1:0] vc_evict_line;
    logic [VICTIM_TAG_WIDTH-1:0] vc_evict_tag;

    // =============================================================
    // Instantiate L1 Cache
    // =============================================================
    l1_cache_dm_with_vc#(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CACHE_BYTES(CACHE_BYTES),
        .LINE_BYTES(LINE_BYTES),
        .VICTIM_TAG_WIDTH(VICTIM_TAG_WIDTH)
    ) DUT (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req_valid(cpu_req_valid),
        .cpu_req_rw(cpu_req_rw),
        .cpu_req_addr(cpu_req_addr),
        .cpu_req_wdata(cpu_req_wdata),
        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_rdata(cpu_resp_rdata),

        .mem_req_valid(l1_mem_req_valid_i),
        .mem_req_rw(l1_mem_req_rw_i),
        .mem_req_addr(l1_mem_req_addr_i),
        .mem_req_wdata(l1_mem_req_wdata_i),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_rdata(mem_resp_rdata),

        .vc_probe_valid(vc_probe_valid),
        .vc_probe_tag(vc_probe_tag),
        .vc_ready(vc_ready),
        .vc_probe_ready(vc_probe_ready),
        .vc_probe_hit(vc_probe_hit),
        .vc_probe_dirty(vc_probe_dirty),
        .vc_probe_line(vc_probe_line),

        .vc_evict_valid(vc_evict_valid),
        .vc_evict_tag(vc_evict_tag),
        .vc_evict_line(vc_evict_line),
        .vc_evict_dirty(vc_evict_dirty),
        .vc_evict_ack(vc_evict_ack)
    );

    // =============================================================
    // Instantiate Victim Cache
    // =============================================================
    victim_cache_controller #(
        .TAG_WIDTH(VICTIM_TAG_WIDTH),
        .LINE_BYTES(LINE_BYTES),
        .NUM_WAYS(4)
    ) VC (
        .clk(clk),
        .rst_n(rst_n),
        .vc_ready(vc_ready),

        .probe_valid(vc_probe_valid),
        .probe_tag(vc_probe_tag),
        .probe_hit(vc_probe_hit),
        .probe_line(vc_probe_line),
        .probe_ready(vc_probe_ready),
        .probe_dirty(vc_probe_dirty),

        .evict_valid(vc_evict_valid),
        .evict_tag(vc_evict_tag),
        .evict_line(vc_evict_line),
        .evict_dirty(vc_evict_dirty),
        .evict_ack(vc_evict_ack),

        .mem_req(vc_mem_req_i),
        .mem_req_write(vc_mem_req_write_i),
        .mem_req_tag(vc_mem_req_tag_i),
        .mem_req_wdata(vc_mem_req_wdata_i),
        .mem_resp_valid(vc_mem_resp_valid_i)
    );

    // =============================================================
    // Memory interface mux (VC has priority)
    // =============================================================
    logic mem_req_valid_i, mem_req_rw_i;
    logic [ADDR_WIDTH-1:0] mem_req_addr_i;
    logic [LINE_BYTES*8-1:0] mem_req_wdata_i;

    always_comb begin
        if (vc_mem_req_i) begin
            mem_req_valid_i = vc_mem_req_i;
            mem_req_rw_i    = vc_mem_req_write_i;
            mem_req_addr_i  = { {(ADDR_WIDTH - VICTIM_TAG_WIDTH){1'b0}}, vc_mem_req_tag_i }; // expand tag to full address // expand tag to full address
            mem_req_wdata_i = vc_mem_req_wdata_i;
        end else begin
            mem_req_valid_i = l1_mem_req_valid_i;
            mem_req_rw_i    = l1_mem_req_rw_i;
            mem_req_addr_i  = l1_mem_req_addr_i;
            mem_req_wdata_i = l1_mem_req_wdata_i;
        end
    end

    assign mem_req_valid = mem_req_valid_i;
    assign mem_req_rw    = mem_req_rw_i;
    assign mem_req_addr  = mem_req_addr_i;
    assign mem_req_wdata = mem_req_wdata_i;

endmodule

