// -----------------------------------------------------------------
// Filename: i2c_slave.v                                             
// 
// Company: 
// Description:                                                     
// 
// 
//                                                                  
// Author: Elvis.Lu<lzyelvis@gmail.com>                            
// Create Date: 03/06/2022                                           
// Comments:                                                        
// 
// -----------------------------------------------------------------


module i2c_slave #(parameter DATA_WIDTH = 32)
(
    input                           clk,
    input                           rst_n,
    input       [6:0]               slave_addr,
    input       [DATA_WIDTH-1:0]    r_data,

    output      [7:0]               data_addr,
    output      [DATA_WIDTH-1:0]    w_data,
    output                          w_en,
    output                          scl,

    inout                           sda
);

localparam DATA_BIT = clogb2(DATA_WIDTH);

////////////////////////////////////////////////////////////////////////
// Define
////////////////////////////////////////////////////////////////////////
reg         [DATA_BIT:0]        data_cnt;
reg         [3:0]               shift_cnt;

reg         [6:0]               slave_addr_r;

reg         [7:0]               ctrl_r;         // r control string(7bit slave addr + 1'b1) second time         
reg         [7:0]               data_addr_r;
reg         [DATA_WIDTH-1:0]    r_data_r;
reg         [DATA_WIDTH-1:0]    w_data_r;

reg                             sda_r;
reg         [1:0]               scl_buf;
reg         [1:0]               sda_buf;

reg                             start_flag;
reg                             stop_flag;
reg                             ack_flag;

wire                            scl_pos;
wire                            scl_neg;
wire                            sda_pos;
wire                            sda_neg;

wire                            start_pulse;
wire                            stop_pulse;

wire                            capture_en;
wire                            shift_en;
wire                            sda_en;
wire                            is_slave;
////////////////////////////////////////////////////////////////////////
// FSM
////////////////////////////////////////////////////////////////////////
localparam IDLE         = 4'd0; 
localparam WR_S_ADDR    = 4'd1; 
localparam WR_S_ACK     = 4'd2; 
localparam WR_D_ADDR    = 4'd3; 
localparam WR_D_ACK     = 4'd4; 
localparam W_DATA       = 4'd5;  
localparam W_ACK        = 4'd6; 
localparam R_S_ADDR     = 4'd7; 
localparam R_ACK        = 4'd8; 
localparam R_DATA       = 4'd9; 
localparam R_WAIT       = 4'd10; 
localparam STOP         = 4'd11; 

reg     [3:0]   state;
reg     [3:0]   next_state;

wire    state_idle          = state == IDLE     ;
wire    state_wr_s_addr     = state == WR_S_ADDR;
wire    state_wr_s_ack      = state == WR_S_ACK ;
wire    state_wr_d_addr     = state == WR_D_ADDR;
wire    state_wr_d_ack      = state == WR_D_ACK ;
wire    state_w_data        = state == W_DATA   ;
wire    state_w_ack         = state == W_ACK    ;
wire    state_r_s_addr      = state == R_S_ADDR ;
wire    state_r_ack         = state == R_ACK    ;
wire    state_r_data        = state == R_DATA   ;
wire    state_r_wait        = state == R_WAIT   ;
wire    state_stop          = state == STOP     ;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        state       <= 4'd0;
    end
    else begin
        state       <= next_state;
    end
end

////////////////////////////////////////////////////////////////////////
// Counter
////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_cnt       <= 4'd0;
    end
    else if(start_flag)
        shift_cnt = 4'd0;
    else if(state_wr_s_addr | state_wr_d_addr | state_w_data | state_r_s_addr | state_r_data) begin
        if(shift_en)
            if(shift_cnt==4'd7)
                shift_cnt   <= 4'd0;
            else
                shift_cnt       <= shift_cnt + 1'b1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_cnt        <= 'd0;
    end
    else if(shift_en) begin
        if(state_idle | start_flag)
            data_cnt        <= 'd0;
        else if(state == W_DATA ) 
            data_cnt        <= data_cnt + 1'b1;
        else if(next_state == R_DATA)
            data_cnt        <= data_cnt + 1'b1;
    end
end

////////////////////////////////////////////////////////////////////////
// edge detect
////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        scl_buf     <= 2'b00;
        sda_buf     <= 2'b00;     
    end
    else begin
        scl_buf     <= {scl_buf[0],scl};
        sda_buf     <= {sda_buf[0],sda};
    end
end

assign scl_pos = ~scl_buf[1] & scl_buf[0];
assign scl_neg = scl_buf[1] & ~scl_buf[0];
assign sda_pos = ~sda_buf[1] & sda_buf[0];
assign sda_neg = sda_buf[1] & ~sda_buf[0];

assign capture_en = scl_pos;
assign shift_en = scl_neg;

assign start_pulse = scl && sda_neg;
assign stop_pulse = scl && sda_pos;

////////////////////////////////////////////////////////////////////////
// Registor
////////////////////////////////////////////////////////////////////////
// read slave address from bus
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        slave_addr_r    <= 7'd0;
    end
    else if(state_idle) begin
        slave_addr_r    <= slave_addr;
    end
end

// generate start/stop flag
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        start_flag      <= 1'b0;
    end
    else if(start_pulse) begin
        start_flag      <= 1'b1;
    end
    else if(shift_en)
        start_flag      <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        stop_flag      <= 1'b0;
    end
    else if(stop_pulse) begin
        stop_flag      <= 1'b1;
    end
    else if(shift_en)
        stop_flag      <= 1'b0;
end

// read ctrl string(slave address + r/w bit) from bus
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ctrl_r          <= 8'd0;
    end
    else if(capture_en && (state_wr_s_addr | state_r_s_addr)) begin
        ctrl_r['d7-shift_cnt]       <= sda;
    end
end

// read data address from bus
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_addr_r     <= 8'd0;
    end
    else if(capture_en && state_wr_d_addr) begin
        data_addr_r['d7-shift_cnt]     <= sda;
    end
end

// generate ack flag
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ack_flag        <= 1'b0;
    end
    else if(state_r_wait) begin
        if(capture_en) begin
            ack_flag    <= ~sda;
        end
    end
    else
        ack_flag        <= 1'b0;
end


// read data from device
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        r_data_r        <= 'd0;
    end
    else if(state_wr_d_ack) begin
        r_data_r        <= r_data;
    end
end

// read write data from bus
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        w_data_r      <= 'd0;
    end
    else if(state_idle)
        w_data_r      <= 'd0;
    else if(state_w_data&&capture_en) begin
        w_data_r[DATA_WIDTH-1-data_cnt]      <= sda;
    end
end

////////////////////////////////////////////////////////////////////////
// CTRL
////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sda_r       <= 1'b1;
    end
    else
        case(next_state)
            WR_S_ACK:
                if(shift_en)
                    sda_r       <= 1'b0;
            WR_D_ACK:
                if(shift_en)
                    sda_r       <= 1'b0;
            W_ACK:
                if(shift_en)
                    sda_r       <= 1'b0;
            R_DATA:
                if(shift_en)
                    sda_r       <= r_data_r[DATA_WIDTH-1-data_cnt];
            R_ACK:
                if(shift_en)
                    sda_r       <= 1'b0;
            default:
                sda_r           <= sda_r;
        endcase
end

assign is_slave = (state_wr_s_addr && slave_addr==ctrl_r[7:1]) | (state_r_ack && slave_addr==ctrl_r[7:1]);

assign sda_en = state_wr_d_ack | state_wr_s_ack | state_w_ack | state_r_ack | state_r_data;

assign sda = sda_en ? sda_r : 1'bz;

assign w_data = w_data_r;
assign data_addr = data_addr_r;
assign w_en = (state_stop && (next_state == IDLE))&&~ctrl_r[0];

////////////////////////////////////////////////////////////////////////
// FSM
////////////////////////////////////////////////////////////////////////
always @(*) begin
    case(state)
        IDLE:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&start_flag) 
                next_state  =   WR_S_ADDR;
            else
                next_state  =   IDLE;
        WR_S_ADDR:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt == 4'd7) begin
                if(is_slave)
                    next_state  =   WR_S_ACK;
                else
                    next_state  =   IDLE;
            end
            else
                next_state  =   WR_S_ADDR;
        WR_S_ACK:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en)
                next_state =    WR_D_ADDR;
            else
                next_state  =   WR_S_ACK;
        WR_D_ADDR:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt==4'd7)
                next_state  =   WR_D_ACK;
            else
                next_state  =   WR_D_ADDR;
        WR_D_ACK:
            if(!rst_n) 
                next_state  =   IDLE;
            else if(shift_en) begin
                next_state  =   W_DATA;
            end
            else
                next_state  =   WR_D_ACK;
        W_DATA:
            if(!rst_n)
                next_state  =   IDLE;
            else if(start_flag && shift_en)
                next_state  = R_S_ADDR;
            else if(shift_en&&shift_cnt==4'd7)
                next_state  =   W_ACK;
            else
                next_state  =   W_DATA;
        W_ACK:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en) begin
                if(data_cnt==DATA_WIDTH)
                    next_state  =   STOP;
                else
                    next_state  =   W_DATA;
            end
            else
                next_state  =   W_ACK;
        R_S_ADDR:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt==4'd7)
                next_state  =   R_ACK;
            else
                next_state  =   R_S_ADDR;
        R_ACK:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en) begin
                if(is_slave && ctrl_r[0])
                    next_state  =   R_DATA;
                else
                    next_state  =   IDLE;  
            end
            else
                next_state  = R_ACK;
        R_DATA:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt==4'd7)
                next_state  =   R_WAIT;
            else
                next_state  =   R_DATA;
        R_WAIT:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en) begin
                if(data_cnt==DATA_WIDTH&&!ack_flag)
                    next_state  =   STOP;
                else if(ack_flag)
                    next_state  =   R_DATA;
                else
                    next_state  = IDLE;
            end
            else
                next_state  =   R_WAIT;
        STOP:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&stop_flag)
                next_state  =   IDLE;
            else
                next_state = STOP;
        default:
            next_state  =   IDLE;
    endcase     
end

function [31:0] clogb2;
    input [31:0] depth;
    begin
        for(clogb2=0;depth>1;clogb2=clogb2 + 1)
            depth = depth >> 1;
    end
endfunction


endmodule