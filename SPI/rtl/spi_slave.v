// -----------------------------------------------------------------
// Filename: spi_slave.v                                             
// 
// Company: 
// Description:                                                     
// 
// | spi mode | CPOL | CPHA | Clock polarity | Phase                                                |
// | -------- | ---- | ---- | -------------- | ---------------------------------------------------- |
// | 0        | 0    | 0    | idles at 0     | trailing edge(neg) shift, leading edge(pos) capture |
// | 1        | 0    | 1    | idles at 0     | leading edge(pos) shift, trailing edge(neg) capture |
// | 2        | 1    | 0    | idles at 1     | trailing edge(pos) shift, leading edge(neg) capture |
// | 3        | 1    | 1    | idles at 1     | leading edge(neg) shift, trailing edge(pos) capture |
//                                                                  
// Author: Elvis.Lu<lzyelvis@gmail.com>                            
// Create Date: 02/12/2022                                           
// Comments:                                                        
// 
// -----------------------------------------------------------------


module spi_slave    #(parameter WIDTH = 8)
(
    input                   clk,
    input                   rst_n,
    input                   sclk,
    input                   cs_en,
    input   [1:0]           mode,
    input   [WIDTH-1:0]     slave_din,
    input                   mosi,
    output                  miso,
    output                  slave_out_rdy,
    output  [WIDTH-1:0]     slave_dout
);

// Define
reg     [1:0]               sclk_buf;

reg     [clogb2(WIDTH)-1:0] shift_cnt;

reg     [WIDTH:0]           slave_i_r;           
reg     [WIDTH:0]           slave_i_r_tmp;
reg     [WIDTH-1:0]         slave_o_r;

wire                        sclk_neg;
wire                        sclk_pos;
wire                        shift_en;
wire                        capture_en;

reg    [1:0]                cs_buf;

// FSM
reg     [1:0]               slave_state;
reg     [1:0]               slave_state_next;

localparam  INIT    = 2'b00;
localparam  TRAN    = 2'b01;
localparam  READY   = 2'b11;

wire slave_INIT = slave_state == INIT;
wire slave_TRAN = slave_state == TRAN;
wire slave_READY = slave_state == READY;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        slave_state     <= 2'b00;
    end
    else begin
        slave_state     <= slave_state_next;
    end
end

// Edge detect
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sclk_buf    <= {mode[1],mode[1]};
        cs_buf      <= 2'b11;
    end
    else begin
        sclk_buf    <= {sclk_buf[0],sclk};
        cs_buf      <= {cs_buf[0],cs_en};
    end
end

assign sclk_neg = ~sclk_buf[0] & sclk_buf[1];
assign sclk_pos = sclk_buf[0] & ~sclk_buf[1];
assign cs_neg   = ~cs_buf[0] & cs_buf[1];

// Counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_cnt       <= 'd0;
    end
    else if(shift_cnt==WIDTH-1) begin
        shift_cnt       <= 'd0;
    end
    else if(slave_TRAN&&shift_en) begin
        shift_cnt       <= shift_cnt + 1'b1;
    end
end


// CTRL
assign shift_en = mode[0] ? sclk_pos : sclk_neg;
assign capture_en = mode[0] ? sclk_neg : sclk_pos;


assign slave_out_rdy = slave_READY;

// din_registor
always @(*) begin
    case(mode)
        2'b00:
            slave_i_r_tmp = {slave_din,1'b0};
        2'b01:
            slave_i_r_tmp = {1'bx,slave_din};
        2'b10:
            slave_i_r_tmp = {1'bx,slave_din};
        2'b11:
            slave_i_r_tmp = {slave_din,1'b0};
        default:
            slave_i_r_tmp = 'd0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        slave_i_r       <= 'd0;
    end
    else if(cs_buf) begin 
        slave_i_r       <= slave_i_r_tmp;
        // slave_i_r       <= mode[0] ? {1'bx,slave_din} : {slave_din,1'b0};
        // slave_i_r       <= {1'bx,slave_din};
    end 
    else if(shift_en) begin
        slave_i_r       <= {slave_i_r[WIDTH-1:0],1'b0};
    end
end

assign miso = slave_i_r[WIDTH];

// dout_registor
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        slave_o_r      <= 'd0;
    end
    else if(capture_en) begin
        slave_o_r      <= {slave_o_r[WIDTH-2:0],mosi};
    end
end

assign slave_dout = slave_o_r;

// STM
always @(*) begin
    case(slave_state)
        INIT:
            if(!rst_n)
                slave_state_next = INIT;
            else if(cs_neg)
                slave_state_next = TRAN;
            else
                slave_state_next = INIT;
        TRAN:
            if(!rst_n)
                slave_state_next = INIT;
            else if(shift_cnt == WIDTH-1)
                slave_state_next = READY;
            else
                slave_state_next = TRAN;
        READY:
            if(!rst_n)
                slave_state_next = INIT;
            else
                slave_state_next = INIT;
        default:
            slave_state_next = INIT;
    endcase 
end


// FUNCTION
function [31:0] clogb2;
    input [31:0] depth;
    begin
        for(clogb2=0;depth>1;clogb2=clogb2 + 1)
            depth = depth >> 1;
    end
endfunction




endmodule