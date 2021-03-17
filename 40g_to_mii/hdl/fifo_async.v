/*
 * Module `fifo_async`
 *
 * Bu modülün temel amacı xpm_fifo_async memory oluşturmaktır.
 * Modülün portları ve parametreleri şu şekildedir:
 *   --> "parameter READ_DATA_WIDTH": Okunacak verinin genişliğini 
 *     temsil eder.
 *   --> "parameter WRITE_DATA_WIDTH": Yazılacak verinin genişliğini 
 *     temsil eder. 
 *   --> "dout": Memory'den çıkan bütün datayı temsil eder.
 *   --> "empty": Memorylerin boş olup olmadığını belirleyen bittir.
 *     Bu sayede, memory boşaldığında okuma işlemi durur.
 *   --> "full": Memory'nin dolu olup olmadığını bilmek için 
 *     vardır. 
 *   --> "din": Memory'e giren bütün datayı temsil eder
 *   --> "rd_clk": Okuma clock'udur ve MII tarafını temsil eder. 
 *     Hızı 25 MHz'tir (1 Gbps hız kullanılmadığı için hızı bu 
 *     şekildedir.).
 *   --> "rd_en": Bu sinyal "bits256_divider" modülünden gelir 
 *     ("r_addr_activater") ve 256 bitlik frame'in parçalara ayrılıp 
 *     4 bit şeklinde gönderildiğini ve yeni bir data alınabileceğini
 *     "fifo_async" modülüne haber eder. 
 *   --> "rst": Bütün sistemi sıfırlar ve synchronous bir
 *     şekilde çalışır. 
 *   --> "wr_clk": Yazma clock'udur ve AXI stream tarafını temsil
 *     eder (40G ETHERNET MODULE). Hızı 156.25 MHz'tir.
 *   --> "wr_en": Memory'e yazılmaya hazır bir datanın 40G modülünden
 *     geldiğini haber eder.
 *   --> "data_valid": Yeni datanın okunduğunu haber eder.
 *   --> "wr_rst_busy": Memory'nin data yazımı için meşgul olup 
 *     olmadığını haber veren bittir. 
 *   --> "rd_rst_busy": Okuma tarafının meşgul olup olmadığının
 *     habercisidir.
 */
 module fifo_async_g40_2_mii #(
    parameter WRITE_DATA_WIDTH = 290,
    parameter READ_DATA_WIDTH  = WRITE_DATA_WIDTH) (
    dout,
    empty,
    full,
    din,
    rd_clk,
    rd_en,
    rst,
    wr_clk,
    wr_en,
    data_valid,
    wr_rst_busy,
    rd_rst_busy
    );

    // --------------------------------
    output [READ_DATA_WIDTH-1:0]  dout;
    output empty;
    output full;
    output data_valid;
    input  [WRITE_DATA_WIDTH-1:0] din;
    input  rd_clk;
    input  rd_en;
    input  rst;
    input  wr_clk;
    input  wr_en;
    output wr_rst_busy,rd_rst_busy;
    // --------------------------------
    
    // Aşağıdaki yorumlar orjinalinden alınmıştır.
    // xpm_fifo_async: Asynchronous FIFO// Xilinx Parameterized Macro, version 2019.1
    xpm_fifo_async #(   
       .CDC_SYNC_STAGES     (2),                // DECIMAL   
       .DOUT_RESET_VALUE    ("0"),              // String   
       .ECC_MODE            ("no_ecc"),         // String   
       .FIFO_MEMORY_TYPE    ("auto"),           // String   
       .FIFO_READ_LATENCY   (1),                // DECIMAL   
       .FIFO_WRITE_DEPTH    (1024),             // DECIMAL   
       .FULL_RESET_VALUE    (1),                // DECIMAL   
       .PROG_EMPTY_THRESH   (5),               // DECIMAL   
       .PROG_FULL_THRESH    (1015),             // DECIMAL   
       .RD_DATA_COUNT_WIDTH (1),                // DECIMAL   
       .READ_DATA_WIDTH     (READ_DATA_WIDTH),  // DECIMAL   
       .READ_MODE           ("std"),            // String   
       .RELATED_CLOCKS      (0),                // DECIMAL   
       .USE_ADV_FEATURES    ("1707"),           // String   
       .WAKEUP_TIME         (0),                // DECIMAL   
       .WRITE_DATA_WIDTH    (WRITE_DATA_WIDTH), // DECIMAL   
       .WR_DATA_COUNT_WIDTH (1)                 // DECIMAL
    )
    xpm_fifo_async_inst (   
       .almost_empty  (),             // 1-bit output: Almost Empty : When asserted, this signal indicates that                                  
                                      // only one more read can be performed before the FIFO goes to empty.   
       .almost_full   (),             // 1-bit output: Almost Full: When asserted, this signal indicates that                                  
                                      // only one more write can be performed before the FIFO is full.   
       .data_valid    (data_valid),   // 1-bit output: Read Data Valid: When asserted, this signal indicates                             
                                      // that valid data is available on the output bus (dout).   
       .dbiterr       (),             // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected                                  
                                      // a double-bit error and data in the FIFO core is corrupted.   
       .dout          (dout),         // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven                                  
                                      // when reading the FIFO.   
       .empty         (empty),        // 1-bit output: Empty Flag: When asserted, this signal indicates that the                                  
                                      // FIFO is empty. Read requests are ignored when the FIFO is empty,                                  
                                      // initiating a read while empty is not destructive to the FIFO.   
       .full          (),             // 1-bit output: Full Flag: When asserted, this signal indicates that the                                  
                                      // FIFO is full. Write requests are ignored when the FIFO is full,                                  
                                      // initiating a write when the FIFO is full is not destructive to the                                  
                                      // contents of the FIFO.   
       .overflow      (),             // 1-bit output: Overflow: This signal indicates that a write request                                  
                                      // (wren) during the prior clock cycle was rejected, because the FIFO is                                  
                                      // full. Overflowing the FIFO is not destructive to the contents of the                                  
                                      // FIFO.   
       .prog_empty    (),             // 1-bit output: Programmable Empty: This signal is asserted when the                                  
                                      // number of words in the FIFO is less than or equal to the programmable                                  
                                      // empty threshold value. It is de-asserted when the number of words in                                  
                                      // the FIFO exceeds the programmable empty threshold value.   
       .prog_full     (full),         // 1-bit output: Programmable Full: This signal is asserted when the                                  
                                      // number of words in the FIFO is greater than or equal to the                                  
                                      // programmable full threshold value. It is de-asserted when the number of                                  
                                      // words in the FIFO is less than the programmable full threshold value.   
       .rd_data_count (),             // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the                                  
                                      // number of words read from the FIFO.   
       .rd_rst_busy   (rd_rst_busy),  // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read                                  
                                      // domain is currently in a reset state.
       .sbiterr       (),             // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected                                  
                                      // and fixed a single-bit error.   
       .underflow     (),             // 1-bit output: Underflow: Indicates that the read request (rd_en) during                                  
                                      // the previous clock cycle was rejected because the FIFO is empty. Under                                  
                                      // flowing the FIFO is not destructive to the FIFO.   
       .wr_ack        (),             // 1-bit output: Write Acknowledge: This signal indicates that a write                                  
                                      // request (wr_en) during the prior clock cycle is succeeded.   
       .wr_data_count (),             // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates                                  
                                      // the number of words written into the FIFO.   
       .wr_rst_busy   (wr_rst_busy),  // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO                                  
                                      // write domain is currently in a reset state.   
       .din           (din),          // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when                                  
                                      // writing the FIFO.   
       .injectdbiterr (1'b0),         // 1-bit input: Double Bit Error Injection: Injects a double bit error if                                  
                                      // the ECC feature is used on block RAMs or UltraRAM macros.   
       .injectsbiterr (1'b0),         // 1-bit input: Single Bit Error Injection: Injects a single bit error if                                  
                                      // the ECC feature is used on block RAMs or UltraRAM macros.   
       .rd_clk        (rd_clk),       // 1-bit input: Read clock: Used for read operation. rd_clk must be a free                                  
                                      // running clock.   
       .rd_en         (rd_en),        // 1-bit input: Read Enable: If the FIFO is not empty, asserting this                                  
                                      // signal causes data (on dout) to be read from the FIFO. Must be held                                  
                                      // active-low when rd_rst_busy is active high.   
       .rst           (rst),          // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be                                  
                                      // unstable at the time of applying reset, but reset must be released only                                  
                                      // after the clock(s) is/are stable.   
       .sleep         (1'b0),         // 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo                                  
                                      // block is in power saving mode.   
       .wr_clk        (wr_clk),       // 1-bit input: Write clock: Used for write operation. wr_clk must be a                                  
                                      // free running clock.   
       .wr_en         (wr_en)         // 1-bit input: Write Enable: If the FIFO is not full, asserting this                                  
                                      // signal causes data (on din) to be written to the FIFO. Must be held                                  
                                      // active-low when rst or wr_rst_busy is active high.  
       );// End of xpm_fifo_async_inst instantiation
    
 endmodule
