# I2C Introduction

**I2C** or  **IIC** , is a [synchronous](https://en.wikipedia.org/wiki/Synchronous_circuit "Synchronous circuit"), multi-controller/multi-target (controller/target), [packet switched](https://en.wikipedia.org/wiki/Packet_switching "Packet switching"), [single-ended](https://en.wikipedia.org/wiki/Single-ended_signaling "Single-ended signaling"), [serial communication](https://en.wikipedia.org/wiki/Serial_communication "Serial communication") [bus](https://en.wikipedia.org/wiki/Bus_(computing)) "Bus (computing)") invented in 1982 by [Philips Semiconductors](https://en.wikipedia.org/wiki/Philips_Semiconductors "Philips Semiconductors"). It is widely used for attaching lower-speed peripheral [ICs](https://en.wikipedia.org/wiki/Integrated_circuit "Integrated circuit") to processors and [microcontrollers](https://en.wikipedia.org/wiki/Microcontroller "Microcontroller") in short-distance, intra-board communication.

## Master Write

### Single byte

![img](https://img2018.cnblogs.com/blog/1426240/201809/1426240-20180916153357946-538149405.png)

### Multi byte

![](https://images2018.cnblogs.com/blog/1057546/201803/1057546-20180318143611658-591157855.jpg)

ACK sent by slave.

## Master Read

### Single byte

![img](https://img2018.cnblogs.com/blog/1426240/201809/1426240-20180916153457230-1442447992.png)

### Multi byte

![img](https://images2018.cnblogs.com/blog/1057546/201803/1057546-20180318143630358-370535921.jpg)

ACK sent by master.

## Design spec

### Master

pos mid capture, neg mid shift

#### I/O

| Port name                | Port type | Description                             |
| ------------------------ | --------- | --------------------------------------- |
| clk                      | input     | system clock                            |
| rst_n                    | input     | system reset                            |
| start                    | input     | master start signal                     |
| mode                     | input     | master r/w mode select(0:read, 1:write) |
| slave_addr[6:0]          | input     | slave select                            |
| data_addr[7:0]           | input     | data address                            |
| data_in[DATA_WIDTH-1:0]  | input     | write data                              |
| data_out[DATA_WIDTH-1:0] | output    | read data                               |
| r_data_rdy               | output    | read data ready                         |
| scl                      | output    | serial clock                            |
| sda                      | inout     | serial data line                        |

#### FSM

| STATE     | Description                   |
| --------- | ----------------------------- |
| IDLE      | system idle state             |
| START     | data transfer start           |
| WR_S_ADDR | write slave address           |
| WR_S_WAIT | wait ack from slave           |
| WR_D_ADDR | write data address            |
| WR_D_WAIT | wait ack from slave           |
| W_DATA    | write byte data               |
| W_WAIT    | wait ack from slave           |
| R_START   | read data start               |
| R_S_ADDR  | write data address(read mode) |
| R_WAIT    | wait ack from slave           |
| R_DATA    | read byte data from slave     |
| R_ACK     | send ack to slave             |
| R_NACK    | send nack to slave            |
| STOP      | transfer stop                 |

state change when shift_en

| STATE     | IDLE     | START    | WR_S_ADDR      | WR_S_WAIT  | WR_D_ADDR      | WR_D_WAIT        | W_DATA         | W_WAIT                         | R_START  | R_S_ADDR       | R_WAIT     | R_DATA                         | R_ACK    | R_NACK   | STOP        |
| --------- | -------- | -------- | -------------- | ---------- | -------------- | ---------------- | -------------- | ------------------------------ | -------- | -------------- | ---------- | ------------------------------ | -------- | -------- | ----------- |
| IDLE      | ???!rst_n | ???!rst_n | ???!rst_n       | ???!rst_n   | ???!rst_n       | ???!rst_n         | ???!rst_n       | ???!rst_n                       | ???!rst_n | ???!rst_n       | ???!rst_n   | ???!rst_n                       | ???!rst_n | ???!rst_n | ???!rst_n/??? |
| START     | ???start  |          |                |            |                |                  |                |                                |          |                |            |                                |          |          |             |
| WR_S_ADDR |          | ???       |                |            |                |                  |                |                                |          |                |            |                                |          |          |             |
| WR_S_WAIT |          |          | ???shift_cnt==8 | ???         |                |                  |                |                                |          |                |            |                                |          |          |             |
| WR_D_ADDR |          |          |                | ???ack_flag | ???             |                  |                |                                |          |                |            |                                |          |          |             |
| WR_D_WAIT |          |          |                |            | ???shift_cnt==8 | ???               |                |                                |          |                |            |                                |          |          |             |
| W_DATA    |          |          |                |            |                | ???ack_flag       | ???             | ???ack_flag                     |          |                |            |                                |          |          |             |
| W_WAIT    |          |          |                |            |                |                  | ???shift_cnt==8 | ???                             |          |                |            |                                |          |          |             |
| R_START   |          |          |                |            |                | ???ack_flag&!mode |                |                                |          |                |            |                                |          |          |             |
| R_S_ADDR  |          |          |                |            |                |                  |                |                                | ???       | ???             |            |                                |          |          |             |
| R_WAIT    |          |          |                |            |                |                  |                |                                |          | ???shift_cnt==8 | ???         |                                |          |          |             |
| R_DATA    |          |          |                |            |                |                  |                |                                |          |                | ???ack_flag | ???                             | ???       |          |             |
| R_ACK     |          |          |                |            |                |                  |                |                                |          |                |            | ???shift_cnt==8                 |          |          |             |
| R_NACK    |          |          |                |            |                |                  |                |                                |          |                |            | ???data_cnt==<br />DATA_WIDTH-1 |          |          |             |
| STOP      |          |          |                |            |                |                  |                | ???data_cnt==<br />DATA_WIDTH-1 |          |                |            |                                |          | ???       |             |

### Slave

slave interface(this demo linked to ram device)

posedge capture, negedge shift

#### I/O

| Port name              | Port type | Description            |
| ---------------------- | --------- | ---------------------- |
| clk                    | input     | system clock           |
| rst_n                  | input     | system reset           |
| slave_addr[6:0]        | input     | slave select           |
| data_addr[7:0]         | output    | data address of device |
| r_data[DATA_WIDTH-1:0] | input     | data read from device  |
| w_data[DATA_WIDTH-1:0] | output    | data write to device   |
| w_en                   | output    | data write enable      |
| scl                    | input     | serial clock           |
| sda                    | inout     | serial data line       |

#### FSM

| STATE     | Description                           |
| --------- | ------------------------------------- |
| IDLE      | system idle state                     |
| WR_S_ADDR | receive write slave address           |
| WR_S_ACK  | send ack to master                    |
| WR_D_ADDR | receive write data address            |
| WR_D_ACK  | send ack to master                    |
| W_DATA    | receive write byte data               |
| W_ACK     | send ack to master                    |
| R_S_ADDR  | receive write data address(read mode) |
| R_ACK     | send ack to master                    |
| R_DATA    | send read byte data                   |
| R_WAIT    | wait ack/nack from master             |

state change when shift_en

| STATE     | IDLE         | WR_S_ADDR                      | WR_S_ACK | WR_D_ADDR      | WR_D_ACK | W_DATA         | W_ACK                          | R_S_ADDR       | R_ACK                      | R_DATA         | R_WAIT                                          | STOP                       |
| --------- | ------------ | ------------------------------ | -------- | -------------- | -------- | -------------- | ------------------------------ | -------------- | -------------------------- | -------------- | ----------------------------------------------- | -------------------------- |
| IDLE      | ???!rst_n     | ???!rst_n/???!is_slave           | ???!rst_n | ???!rst_n       | ???!rst_n | ???!rst_n       | ???!rst_n                       | ???!rst_n       | ???!rst_n/??? !???            | ???!rst_n       | ???!rst_n                                        | ???!rst_n/<br />???stop_flag |
| WR_S_ADDR | ???start_flag | ???                             |          |                |          |                |                                |                |                            |                |                                                 |                            |
| WR_S_ACK  |              | ???shift_cnt==7<br />& is_slave | ???       |                |          |                |                                |                |                            |                |                                                 |                            |
| WR_D_ADDR |              |                                | ???       | ???             |          |                |                                |                |                            |                |                                                 |                            |
| WR_D_ACK  |              |                                |          | ???shift_cnt==7 | ???       |                |                                |                |                            |                |                                                 |                            |
| W_DATA    |              |                                |          |                | ???       | ???             | ???                             |                |                            |                |                                                 |                            |
| W_ACK     |              |                                |          |                |          | ???shift_cnt==7 | ???                             |                |                            |                |                                                 |                            |
| R_S_ADDR  |              |                                |          |                |          | ???start_flag   |                                | ???             |                            |                |                                                 |                            |
| R_ACK     |              |                                |          |                |          |                |                                | ???shift_cnt==7 | ???                         |                |                                                 |                            |
| R_DATA    |              |                                |          |                |          |                |                                |                | ???ctrl_r[0]<br />&is_slave | ???             | ???ack_flag                                      |                            |
| R_WAIT    |              |                                |          |                |          |                |                                |                |                            | ???shift_cnt==7 | ???                                              |                            |
| STOP      |              |                                |          |                |          |                | ???data_cnt==<br />DATA_WIDTH-1 |                |                            |                | ???data_cnt==<br />DATA_WIDTH-1<br />& !ack_flag | ???                         |


## Reference

* https://en.wikipedia.org/wiki/I%C2%B2C
* https://www.cnblogs.com/liujinggang/p/9656358.html
* https://www.cnblogs.com/ninghechuan/p/8595423.html
* https://www.cnblogs.com/ninghechuan/p/9534893.html
