// -----------------------------------------------------------------
// Filename: i2c_master.v                                             
// 
// Company: 
// Description:                                                     
// 
// 
//                                                                  
// Author: Elvis.Lu<lzyelvis@gmail.com>                            
// Create Date: 06/03/2022                                           
// Comments:                                                        
// 
// -----------------------------------------------------------------


module i2c_master #(parameter DATA_WIDTH = 32, parameter DIV = 200)
(
    input                           clk,
    input                           rst_n,
    input                           start,
    input                           mode,
    input       [6:0]               slave_addr,
    input       [7:0]               data_addr,
    input       [DATA_WIDTH-1:0]    data_in,
    output      [DATA_WIDTH-1:0]    data_out,
    output                          data_rdy,
    output                          scl,
    inout                           sda
);

localparam DIV_NEG_MID = (DIV>>2)-1;
localparam DIV_C = (DIV>>1)-1;
localparam DIV_POS_MID = (DIV_NEG_MID + DIV_C)+1;

localparam BYTE_NUM = 1 + 1 + 1 + DATA_WIDTH/8;
localparam W_BIT_NUM = (BYTE_NUM-1)*8;
localparam R_BIT_NUM = BYTE_NUM*8;
localparam BYTE_WIDTH = clogb2(BYTE_NUM);
localparam DIV_WIDTH = clogb2(DIV); 
localparam DATA_BIT = clogb2(DATA_WIDTH);
////////////////////////////////////////////////////////////////////////
// Define
////////////////////////////////////////////////////////////////////////
reg         [DIV_WIDTH-1:0]     div_cnt;
reg                             sclk;

reg         [DATA_BIT:0]        data_cnt;
reg         [3:0]               shift_cnt;

reg         [1:0]               sclk_buf;

reg         [7:0]               wr_ctrl_str;        // w/r control string(7 bit slave addr + 1'b0)
reg         [7:0]               r_ctrl_str;         // r control string(7bit slave addr + 1'b1) second time         
reg         [7:0]               wr_data_addr;
reg         [DATA_WIDTH-1:0]    data_buf;
reg                             mode_r;

reg                             sda_r;

reg                             start_flag;
reg                             ack_flag;

reg         [DATA_WIDTH-1:0]    data_out_r;

wire                            sclk_pos;
wire                            sclk_neg;


wire                            capture_en;
wire                            shift_en;
wire                            scl_en;
wire                            sda_en;
////////////////////////////////////////////////////////////////////////
// FSM
////////////////////////////////////////////////////////////////////////
localparam IDLE        = 4'd0; 
localparam START       = 4'd1; 
localparam WR_S_ADDR   = 4'd2; 
localparam WR_S_WAIT   = 4'd3; 
localparam WR_D_ADDR   = 4'd4; 
localparam WR_D_WAIT   = 4'd5; 
localparam W_DATA      = 4'd6;  
localparam W_WAIT      = 4'd7; 
localparam R_START     = 4'd8; 
localparam R_S_ADDR    = 4'd9; 
localparam R_WAIT      = 4'd10; 
localparam R_DATA      = 4'd11; 
localparam R_ACK       = 4'd12; 
localparam R_NACK      = 4'd13; 
localparam STOP        = 4'd14; 

reg     [3:0]   state;
reg     [3:0]   next_state;

wire    state_idle         = state == IDLE     ;
wire    state_start        = state == START    ;
wire    state_wr_s_addr    = state == WR_S_ADDR;
wire    state_wr_s_wait    = state == WR_S_WAIT;
wire    state_wr_d_addr    = state == WR_D_ADDR;
wire    state_wr_d_wait    = state == WR_D_WAIT;
wire    state_w_data       = state == W_DATA   ;
wire    state_w_wait       = state == W_WAIT   ;
wire    state_r_start      = state == R_START  ;
wire    state_r_s_addr     = state == R_S_ADDR ;
wire    state_r_wait       = state == R_WAIT   ;
wire    state_r_data       = state == R_DATA   ;
wire    state_r_ack        = state == R_ACK    ;
wire    state_r_nack       = state == R_NACK   ;
wire    state_stop         = state == STOP     ;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        state       <= 4'd0;
    end
    else begin
        state       <= next_state;
    end
end

////////////////////////////////////////////////////////////////////////
// Clock_div
////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        div_cnt     <= 'd0;
    end
    else if(div_cnt == DIV/2 -1) begin
        div_cnt     <= 'd0;
    end
    else begin
        div_cnt     <= div_cnt + 1'b1;
    end 
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sclk        <= 1'b0;
    end
    else if(div_cnt == DIV/ -1) begin
        sclk        <= ~sclk;
    end
end



always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        sclk_buf    <= 2'b00;
    end
    else begin
        sclk_buf    <= {sclk_buf[0],sclk};
    end
end

assign sclk_pos = ~sclk_buf[1] & sclk_buf[0];
assign sclk_neg = sclk_buf[1] & ~sclk_buf[0];

assign capture_en = sclk_pos;
assign shift_en = sclk_neg;

////////////////////////////////////////////////////////////////////////
// Counter
////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_cnt       <= 4'd0;
    end
    else if (shift_en) begin
        if(shift_cnt==4'd8)
            shift_cnt   <= 4'd0;
        else if(next_state==WR_S_ADDR|next_state==WR_D_ADDR|next_state==W_DATA|next_state==R_S_ADDR|next_state==R_DATA)
            shift_cnt   <= shift_cnt + 1'b1;
    end
    // else if(next_state==R_DATA&&capture_en)
        // shift_cnt       <= shift_cnt + 1'b1;
    // else if(state_wr_s_addr | state_wr_d_addr | state_w_data | state_r_s_addr | state_r_data) begin
        // if(shift_en)
            // if(shift_cnt==4'd8)
                // shift_cnt   <= 4'd0;
            // else
                // shift_cnt       <= shift_cnt + 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_cnt        <= 'd0;
    end
    else if(shift_en) begin
        if(state_idle)
            data_cnt        <= 'd0;
        else if(next_state == W_DATA) begin
            data_cnt        <= data_cnt + 1'b1;
        end
        else if(state_r_data) begin
            data_cnt        <= data_cnt + 1'b1;
        end
    end
end


////////////////////////////////////////////////////////////////////////
// Registor
////////////////////////////////////////////////////////////////////////
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        start_flag      <= 1'b0;
    end
    else if(state_idle&&start) begin
        start_flag      <= 1'b1;
    end
    else if(shift_en)
        start_flag      <= 1'b0;
end



always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wr_ctrl_str     <= 8'd0;
        wr_data_addr    <= 8'd0;
        data_buf        <= 'd0;
        r_ctrl_str      <= 8'd0;
        mode_r          <= 1'b0;
    end
    else if(state_idle&start) begin
        wr_ctrl_str     <= {slave_addr,1'b0};
        wr_data_addr    <= data_addr;
        data_buf        <= data_in;
        r_ctrl_str      <= {slave_addr,1'b1};
        mode_r          <= mode;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ack_flag        <= 1'b0;
    end
    else if(state_wr_s_wait | state_wr_d_wait | state_w_wait | state_r_wait) begin
        if(capture_en) begin
            ack_flag    <= ~sda;
        end
    end
    else
        ack_flag        <= 1'b0;
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_out_r      <= 'd0;
    end
    else if(state_idle)
        data_out_r      <= 'd0;
    else if(state_r_data&&capture_en) begin
        data_out_r[DATA_WIDTH-1-data_cnt]      <= sda;
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
            IDLE: 
                if(shift_en)
                    sda_r       <= 1'b1;
            START:
                if(capture_en)
                    sda_r       <= 1'b0;
            WR_S_ADDR:
                if(shift_en)
                    sda_r       <= wr_ctrl_str[7-shift_cnt];
            WR_D_ADDR:
                if(shift_en)
                    sda_r       <= wr_data_addr[7-shift_cnt];
            W_DATA:
                if(shift_en)
                    sda_r       <= data_buf[DATA_WIDTH-1-data_cnt];
            W_WAIT:
                if(shift_en)
                    sda_r       <= 1'b0;        // reset sda_r
            R_START:
                if(shift_en)
                    sda_r       <= 1'b1;
                else if(capture_en)
                    sda_r       <= 1'b0;
            R_S_ADDR:
                if(shift_en)
                    sda_r       <= r_ctrl_str[7-shift_cnt];
            R_ACK:
                if(shift_en)
                    sda_r       <= 1'b0;
            R_NACK:
                if(shift_en)
                    sda_r       <= 1'b1;
            STOP:
                if(shift_en)
                    sda_r       <= 1'b0;
                else if(capture_en)
                    sda_r       <= 1'b1;
            default:
                sda_r           <= sda_r;
        endcase
end



assign sda_en = state_start | state_wr_s_addr | state_wr_d_addr | state_w_data | state_r_start 
                | state_r_s_addr | state_r_ack | state_r_nack | state_stop;


assign sda = sda_en ? sda_r : 1'bz;

assign scl =  sclk;

assign data_out = data_out_r;
assign data_rdy = (state_stop && (next_state == IDLE));
////////////////////////////////////////////////////////////////////////
// FSM
////////////////////////////////////////////////////////////////////////
always @(*) begin
    case(state)
        IDLE:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&start_flag) 
                next_state  =   START;
            else
                next_state  =   IDLE;
        START:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en)
                next_state  =   WR_S_ADDR;
            else
                next_state  =   START;
        WR_S_ADDR:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt == 4'd8)
                next_state  =   WR_S_WAIT;
            else
                next_state  =   WR_S_ADDR;
        WR_S_WAIT:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&ack_flag)
                next_state =    WR_D_ADDR;
            else
                next_state  =   WR_S_WAIT;
        WR_D_ADDR:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt==4'd8)
                next_state  =   WR_D_WAIT;
            else
                next_state  =   WR_D_ADDR;
        WR_D_WAIT:
            if(!rst_n) 
                next_state  =   IDLE;
            else if(shift_en&&ack_flag) begin
                if(!mode)
                    next_state  =   R_START;
                else
                    next_state  =   W_DATA;
            end
            else
                next_state  =   WR_D_WAIT;
        W_DATA:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt==4'd8)
                next_state  =   W_WAIT;
            else
                next_state  =   W_DATA;
        W_WAIT:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&ack_flag) begin
                if(data_cnt==DATA_WIDTH)
                    next_state  =   STOP;
                else
                    next_state  =   W_DATA;
            end
            else
                next_state  =   W_WAIT;
        R_START:
            if(!rst_n) 
                next_state  =   IDLE;
            else if(shift_en)
                next_state  =   R_S_ADDR;
            else
                next_state  =   R_START;
        R_S_ADDR:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&shift_cnt==4'd8)
                next_state  =   R_WAIT;
            else
                next_state  =   R_S_ADDR;
        R_WAIT:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&ack_flag)
                next_state  =   R_DATA;
            else
                next_state  = R_WAIT;
        R_DATA:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en&&data_cnt==DATA_WIDTH-1)
                next_state  =   R_NACK;
            else if(shift_en&&shift_cnt==4'd8)
                next_state  =   R_ACK;
            else
                next_state  =   R_DATA;
        R_ACK:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en)
                next_state  =   R_DATA;
            else
                next_state  =   R_ACK;
        R_NACK:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en)
                next_state  =   STOP;
            else
                next_state  =   R_NACK;
        STOP:
            if(!rst_n)
                next_state  =   IDLE;
            else if(shift_en)
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