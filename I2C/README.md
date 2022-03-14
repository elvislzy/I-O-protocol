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
| IDLE      | ①!rst_n | ①!rst_n | ①!rst_n       | ①!rst_n   | ①!rst_n       | ①!rst_n         | ①!rst_n       | ①!rst_n                       | ①!rst_n | ①!rst_n       | ①!rst_n   | ①!rst_n                       | ①!rst_n | ①!rst_n | ①!rst_n/② |
| START     | ②start  |          |                |            |                |                  |                |                                |          |                |            |                                |          |          |             |
| WR_S_ADDR |          | ②       |                |            |                |                  |                |                                |          |                |            |                                |          |          |             |
| WR_S_WAIT |          |          | ②shift_cnt==8 | ③         |                |                  |                |                                |          |                |            |                                |          |          |             |
| WR_D_ADDR |          |          |                | ②ack_flag | ③             |                  |                |                                |          |                |            |                                |          |          |             |
| WR_D_WAIT |          |          |                |            | ②shift_cnt==8 | ④               |                |                                |          |                |            |                                |          |          |             |
| W_DATA    |          |          |                |            |                | ③ack_flag       | ③             | ③ack_flag                     |          |                |            |                                |          |          |             |
| W_WAIT    |          |          |                |            |                |                  | ②shift_cnt==8 | ④                             |          |                |            |                                |          |          |             |
| R_START   |          |          |                |            |                | ②ack_flag&!mode |                |                                |          |                |            |                                |          |          |             |
| R_S_ADDR  |          |          |                |            |                |                  |                |                                | ②       | ③             |            |                                |          |          |             |
| R_WAIT    |          |          |                |            |                |                  |                |                                |          | ②shift_cnt==8 | ③         |                                |          |          |             |
| R_DATA    |          |          |                |            |                |                  |                |                                |          |                | ②ack_flag | ④                             | ②       |          |             |
| R_ACK     |          |          |                |            |                |                  |                |                                |          |                |            | ③shift_cnt==8                 |          |          |             |
| R_NACK    |          |          |                |            |                |                  |                |                                |          |                |            | ②data_cnt==<br />DATA_WIDTH-1 |          |          |             |
| STOP      |          |          |                |            |                |                  |                | ②data_cnt==<br />DATA_WIDTH-1 |          |                |            |                                |          | ②       |             |

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
| IDLE      | ①!rst_n     | ①!rst_n/③!is_slave           | ①!rst_n | ①!rst_n       | ①!rst_n | ①!rst_n       | ①!rst_n                       | ①!rst_n       | ①!rst_n/④ !②            | ①!rst_n       | ①!rst_n                                        | ①!rst_n/<br />②stop_flag |
| WR_S_ADDR | ②start_flag | ④                             |          |                |          |                |                                |                |                            |                |                                                 |                            |
| WR_S_ACK  |              | ②shift_cnt==7<br />& is_slave | ③       |                |          |                |                                |                |                            |                |                                                 |                            |
| WR_D_ADDR |              |                                | ②       | ③             |          |                |                                |                |                            |                |                                                 |                            |
| WR_D_ACK  |              |                                |          | ②shift_cnt==7 | ③       |                |                                |                |                            |                |                                                 |                            |
| W_DATA    |              |                                |          |                | ②       | ④             | ③                             |                |                            |                |                                                 |                            |
| W_ACK     |              |                                |          |                |          | ③shift_cnt==7 | ④                             |                |                            |                |                                                 |                            |
| R_S_ADDR  |              |                                |          |                |          | ②start_flag   |                                | ③             |                            |                |                                                 |                            |
| R_ACK     |              |                                |          |                |          |                |                                | ②shift_cnt==7 | ③                         |                |                                                 |                            |
| R_DATA    |              |                                |          |                |          |                |                                |                | ②ctrl_r[0]<br />&is_slave | ③             | ③ack_flag                                      |                            |
| R_WAIT    |              |                                |          |                |          |                |                                |                |                            | ②shift_cnt==7 | ④                                              |                            |
| STOP      |              |                                |          |                |          |                | ②data_cnt==<br />DATA_WIDTH-1 |                |                            |                | ②data_cnt==<br />DATA_WIDTH-1<br />& !ack_flag | ③                         |


## Reference

* https://en.wikipedia.org/wiki/I%C2%B2C
* https://www.cnblogs.com/liujinggang/p/9656358.html
* https://www.cnblogs.com/ninghechuan/p/8595423.html
* https://www.cnblogs.com/ninghechuan/p/9534893.html
