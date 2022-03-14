// -----------------------------------------------------------------
// Filename: spi_master.v                                             
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
// Create Date: 02/08/2022                                           
// Comments:                                                        
// 
// -----------------------------------------------------------------


module spi_master #(parameter WIDTH = 8, parameter DIV_N = 2)
(
    input                   clk,
    input                   rst_n,
    input   [WIDTH-1:0]     master_din,
    input                   spi_start,
    input                   miso,
    input   [1:0]           mode,
    output                  sclk,
    output                  cs_en,
    output                  mosi,
    output                  spi_rdy,
    output  [WIDTH-1:0]     master_dout
);

// Define

reg [clogb2(DIV_N)-1:0] de_cnt;
reg [clogb2(WIDTH*DIV_N)-1:0] tr_cnt;
reg [clogb2(DIV_N)-1:0] div_cnt;

reg [WIDTH:0]           din_r;
reg [WIDTH:0]           din_r_tmp;
reg [WIDTH-1:0]         dout_r;

reg                     sclock;

wire                    shift_en;
wire                    capture_en;

reg                     cs_en_dly;

// STM
reg [1:0]   state;
reg [1:0]   next_state;

localparam  INIT    = 2'b00;
localparam  PRE     = 2'b01;
localparam  TRAN    = 2'b11;
localparam  FINISH  = 2'b10;

wire state_init     = state == INIT;
wire state_pre      = state == PRE;
wire state_tran     = state == TRAN;
wire state_finish   = state == FINISH;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state       <= 2'b00;
    end
    else begin
        state       <= next_state;
    end
end

// gen sclk
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        div_cnt     <= 'd0;
    end
    else if(div_cnt == (DIV_N/2)-1)
        div_cnt     <= 'd0;
    else
        div_cnt     <= div_cnt + 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sclock      <= mode[1];
    end
    else if(div_cnt == (DIV_N/2)-1) begin
        sclock      <= ~sclock;
    end
end

assign sclk = state_tran ? sclock : mode[1]; 
// assign sclk = mode[1] ? ~sclock0 : sclock0;

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        de_cnt      <= 'd0;
    end
    else if(de_cnt==DIV_N-1) begin
        de_cnt      <= 'd0;
    end
    else if(state_pre | state_finish) begin
        de_cnt      <= de_cnt + 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tr_cnt      <= 'd0;
    end
    else if(tr_cnt == WIDTH-1) begin
        tr_cnt      <= 'd0;
    end
    else if(state_tran&&shift_en) begin
        tr_cnt      <= tr_cnt + 1'b1;
    end
end

//assign shift_en = state_tran ? mode[0] 
//                ? ~tr_cnt[0]:tr_cnt[0]
//                : 1'b0;
//assign capture_en = state_tran ? mode[0] 
//                  ? tr_cnt[0]:~tr_cnt[0]
//                  : 1'b0;

reg     [1:0]               sclk_buf;
wire                        sclk_neg;
wire                        sclk_pos;
// Edge detect
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sclk_buf    <= {mode[1],mode[1]};
    end
    else begin
        sclk_buf    <= {sclk_buf[0],sclk};
    end
end

assign sclk_neg = ~sclk_buf[0] & sclk_buf[1];
assign sclk_pos = sclk_buf[0] & ~sclk_buf[1];
assign shift_en = mode[0] ? sclk_pos : sclk_neg;
assign capture_en = mode[0] ? sclk_neg : sclk_pos;

assign cs_en = state_init; 


// din_registor
always @(*) begin
    case(mode)
        2'b00:
            din_r_tmp = {master_din,1'b0};
        2'b01:
            din_r_tmp = {1'bx,master_din};
        2'b10:
            din_r_tmp = {1'bx,master_din};
        2'b11:
            din_r_tmp = {master_din,1'b0};
        default:
            din_r_tmp = 'd0;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        din_r       <= 'd0;
    end
    else if(spi_start) begin 
        din_r       <= din_r_tmp;
        // din_r       <= {1'bx,master_din};
    end
    else if(shift_en) begin
        din_r       <= {din_r[WIDTH-1:0],1'b0};
    end
end

assign mosi = din_r[WIDTH];

// dout_registor
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        dout_r      <= 'd0;
    end
    else if(capture_en) begin
        dout_r      <= {dout_r[WIDTH-2:0],miso};
    end
end

assign master_dout = dout_r;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cs_en_dly     <= 1'b1;
    end
    else
        cs_en_dly     <= cs_en;
end

assign spi_rdy = cs_en & ~cs_en_dly;

// STM

always @(*) begin
    case(state)
        INIT:
            if(!rst_n)
                next_state  = INIT;
            else if(spi_start)
                next_state  = PRE;
            else
                next_state  = INIT;
        PRE:
            if(!rst_n)
                next_state  = INIT;
            else if(de_cnt==DIV_N-1)
                next_state  = TRAN;
            else
                next_state  = PRE;
        TRAN:
            if(!rst_n)
                next_state  = INIT;
            else if(tr_cnt == WIDTH-1)
                next_state  = FINISH;
            else
                next_state  = TRAN;
        FINISH:
            if(!rst_n)
                next_state = INIT;
            else if(de_cnt == DIV_N-1)
                next_state = INIT;
            else
                next_state = FINISH;
        default:
            next_state  = INIT;
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