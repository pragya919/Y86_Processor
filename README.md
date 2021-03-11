# Y86 5-Stage Pipelined Processor Architecture
This is my 64-bit Y86 processor designed to support 5-Stage Pipeline structure. The 5 stages are Fetch, Decode, Execute, Memory and Writeback. All the stages are pipelined and take care of pipeline hazards by stalling and forwarding as well! 

## How to run
Fork the repository on to your local machine and run the following commands - 

To install verilog: 
```	sudo apt-get install verilog ```

To install Gtkwave:
``` sudo apt-get install gtkwave ```

To compile and see the output:

1. ```iverilog main_temp_tb.v main_temp.v ```

2. ```./a.out```

3. ```gtkwave main_temp_tb.vcd```


## Instructions supported
1. halt
2. nop
3. cmovxx
4. irmovq
5. rmmovq
6. mrmovq
7. OPq
8. jXX
9. call
10. ret
11. pushq
12. popq

All the other details can be found in [Report]()
