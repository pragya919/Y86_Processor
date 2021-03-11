`include "fetch.v"
`include "decode.v"
`include "execute.v"
`include "memory.v"

module main(clock,W_stat);

    input clock;
    output [2:0] W_stat;

    //Instructions
    parameter IHALT = 4'h0;
    parameter INOP = 4'h1;
    parameter IRRMOVQ = 4'h2;
    parameter IIRMOVQ = 4'h3;
    parameter IRMMOVQ = 4'h4;
    parameter IMRMOVQ = 4'h5;
    parameter IOPQ = 4'h6;
    parameter IJXX = 4'h7;
    parameter ICALL = 4'h8;
    parameter IRET = 4'h9;
    parameter IPUSHQ = 4'hA;
    parameter IPOPQ = 4'hB;
    
    // Function codes
    parameter FNONE = 4'h0;
    // Jump conditions
    parameter UNCOND = 4'h0;
    // Register IDs
    parameter RRSP = 4'h4;
    parameter RRBP = 4'h5;
    parameter RNONE = 4'hF;
    // ALU operations
    parameter ALUADD = 4'h0;
    // Status conditions
    parameter SBUB = 3'h0;
    parameter SAOK = 3'h1;
    parameter SHLT = 3'h2;
    parameter SADR = 3'h3;
    parameter SINS = 3'h4;

    // Fetch stage signals
    wire [63:0] f_predPC, F_predPC, f_pc;
    wire imem_error;
    wire [ 2:0] f_stat;
    wire [7:0] f_ibyte;
    wire[71:0] f_ibytes;
    wire [ 3:0] f_icode;
    wire [ 3:0] f_ifun;
    wire [ 3:0] f_rA;
    wire [ 3:0] f_rB;
    wire [63:0] f_valC;
    wire [63:0] f_valP;
    wire need_regids;
    wire need_valC;
    wire instr_valid;
    wire F_stall, F_bubble, F_reset;


    //Decode stage signals
    wire [ 2:0] D_stat;
    wire [63:0] D_pc;
    wire [ 3:0] D_icode;
    wire [ 3:0] D_ifun;
    wire [ 3:0] D_rA;
    wire [ 3:0] D_rB;
    wire [63:0] D_valC;
    wire [63:0] D_valP;
    wire [63:0] d_valA;
    wire [63:0] d_valB;
    wire [63:0] d_rvalA;
    wire [63:0] d_rvalB;
    wire [ 3:0] d_dstE;
    wire [ 3:0] d_dstM;
    wire [ 3:0] d_srcA;
    wire [ 3:0] d_srcB;
    wire D_stall , D_bubble, D_reset;


    //Execute stage signals
    wire [ 2:0] E_stat;
    wire [63:0] E_pc;
    wire [ 3:0] E_icode;
    wire [ 3:0] E_ifun;
    wire [63:0] E_valC;
    wire [63:0] E_valA;
    wire [63:0] E_valB;
    wire [ 3:0] E_dstE;
    wire [ 3:0] E_dstM;
    wire [ 3:0] E_srcA;
    wire [ 3:0] E_srcB;
    wire [63:0] aluA;
    wire [63:0] aluB;
    wire set_cc;
    wire [ 2:0] cc;
    wire [ 2:0] new_cc;
    wire [ 3:0] alufun;
    wire e_Cnd;
    wire [63:0] e_valE;
    wire [63:0] e_valA;
    wire [ 3:0] e_dstE;
    wire E_stall, E_bubble;


    //Memory stage signals
    wire [ 2:0] M_stat;
    wire [63:0] M_pc;
    wire [ 3:0] M_icode;
    wire [ 3:0] M_ifun;
    wire M_Cnd;
    wire [63:0] M_valE;
    wire [63:0] M_valA;
    wire [ 3:0] M_dstE;
    wire [ 3:0] M_dstM;
    wire [ 2:0] m_stat;
    wire [63:0] mem_addr;
    wire [63:0] mem_data;
    wire mem_read;
    wire mem_write;
    wire dmem_error;
    wire [63:0] m_valM;
    wire M_stall, M_bubble,M_reset;


    //Writeback stage signals
    wire [ 2:0] W_stat;
    wire [63:0] W_pc;
    wire [ 3:0] W_icode;
    wire [63:0] W_valE;
    wire [63:0] W_valM;
    wire [ 3:0] W_dstE;
    wire [ 3:0] W_dstM;
    wire [63:0] w_valE;
    wire [63:0] w_valM;
    wire [ 3:0] w_dstE;
    wire [ 3:0] w_dstM;
    wire W_stall, W_bubble, resetting;

    

    //initialising
    assign resetting = 1;

    assign imem_error = 1'b0;
    
    assign dmem_error = 1'b0;

    //FETCH LOGIC
    
    //Instruction valid block
    assign instr_valid = 
    f_icode == INOP ? 1'b1 :
    f_icode == IHALT ? 1'b1 :
    f_icode == IRRMOVQ ? 1'b1 :
    f_icode == IIRMOVQ ? 1'b1 :
    f_icode == IRMMOVQ ? 1'b1 :
    f_icode == IMRMOVQ ? 1'b1 :
    f_icode == IOPQ ? 1'b1 :
    f_icode == IJXX ? 1'b1 :
    f_icode == ICALL ? 1'b1 :
    f_icode == IRET ? 1'b1 :
    f_icode == IPUSHQ ? 1'b1 :
    f_icode == IPOPQ ? 1'b1 : 1'b0;

    //Select PC block
    assign f_pc =(((M_icode == IJXX) & ~M_Cnd) ? M_valA : (W_icode == IRET) ? W_valM :F_predPC);
    
    //Stat block
    assign f_stat =(imem_error ? SADR : ~instr_valid ? SINS : (f_icode == IHALT) ? SHLT :SAOK);
    
    //Need regids block
    assign need_regids =
    f_icode == IRRMOVQ ? 1'b1:
    f_icode == IOPQ ? 1'b1:
    f_icode == IPUSHQ ? 1'b1:
    f_icode ==IPOPQ ? 1'b1:
    f_icode == IIRMOVQ ? 1'b1:
    f_icode == IRMMOVQ ? 1'b1:
    f_icode == IMRMOVQ ? 1'b1: 1'b0;

    //Need ValC block
    assign need_valC =(f_icode == IIRMOVQ | f_icode == IRMMOVQ | f_icode == IMRMOVQ | f_icode== IJXX | f_icode == ICALL);
    
    //Predict PC block
    assign f_predPC =((f_icode == IJXX | f_icode == ICALL) ? f_valC : f_valP);
    
    //Instruction Memory block
    InstructionMemory I(f_pc,f_ibyte[7:0],f_ibytes[71:0],imem_error);

    //Split block
    split split(f_ibyte[7:0], f_icode, f_ifun);
    
    //Align block
    align align(f_ibytes[71:0], need_regids, f_rA, f_rB, f_valC);
    
    //PC increment block
    pc_increment pci(f_pc, need_regids, need_valC, f_valP);


    //DECODE LOGIC

    //SrcA block
    assign d_srcA =
    D_icode == IRRMOVQ ? D_rA: 
    D_icode == IRMMOVQ ? D_rA:
    D_icode == IOPQ ? D_rA:
    D_icode== IPUSHQ ? D_rA :
    D_icode == IPOPQ ? RRSP:
    D_icode == IRET ? RRSP :RNONE;

    //SrcB block
    assign d_srcB =
    D_icode == IOPQ ? D_rB:
    D_icode == IRMMOVQ ? D_rB:
    D_icode == IMRMOVQ ? D_rB :
    D_icode == IPUSHQ ? RRSP:
    D_icode == IPOPQ ? RRSP:
    D_icode == ICALL ? RRSP:  
    D_icode== IRET ? RRSP : RNONE;

    //DstE block
    assign d_dstE =
    D_icode == IRRMOVQ ? D_rB:
    D_icode == IIRMOVQ ? D_rB :
    D_icode == IOPQ ? D_rB :
    D_icode == IPUSHQ ? RRSP:
    D_icode == IPOPQ ? RRSP:
    D_icode == ICALL ? RRSP: 
    D_icode== IRET ? RRSP : RNONE;

    //DstM block
    assign d_dstM =((D_icode == IMRMOVQ | D_icode == IPOPQ) ? D_rA : RNONE);
    
    //Sel+Fwd A block
    assign d_valA =
    D_icode == ICALL ? D_valP: 
    D_icode == IJXX ? D_valP :
    d_srcA == e_dstE ? e_valE : 
    d_srcA == M_dstM ? m_valM : 
    d_srcA == M_dstE ? M_valE :
    d_srcA == W_dstM ? W_valM : 
    d_srcA == W_dstE ? W_valE : d_rvalA;

    //Fwd B block
    assign d_valB =
    d_srcB == e_dstE ? e_valE : 
    d_srcB == M_dstM ? m_valM : 
    d_srcB== M_dstE ? M_valE : 
    d_srcB == W_dstM ? W_valM : 
    d_srcB ==W_dstE ? W_valE : d_rvalB;

    //Register File
    output [63:0] rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, r8, r9, r10, r11, r12, r13, r14;
    regfile regf(w_dstE, w_valE, w_dstM, w_valM, d_srcA, d_rvalA, d_srcB, d_rvalB, resetting, clock, rax, rcx, rdx, rbx, rsp, rbp, rsi, rdi, r8, r9, r10, r11, r12, r13, r14);

    
    //EXECUTE LOGIC
    
    //ALU A block
    assign aluA =
    E_icode == IRRMOVQ ? E_valA: 
    E_icode == IOPQ ? E_valA : 
    E_icode == IIRMOVQ ? E_valC:
    E_icode == IRMMOVQ ? E_valC: 
    E_icode == IMRMOVQ ? E_valC : 
    E_icode ==ICALL ? -8:
    E_icode == IPUSHQ ? -8 : 
    E_icode == IRET ? 8:
    E_icode == IPOPQ ? 8 : 0;

    //ALU B block
    assign aluB =
    E_icode == IRMMOVQ ? E_valB:
    E_icode == IMRMOVQ ? E_valB:
    E_icode == IOPQ ? E_valB:
    E_icode== ICALL ? E_valB:
    E_icode == IPUSHQ ? E_valB:
    E_icode == IRET ? E_valB:
    E_icode == IPOPQ ? E_valB : 
    E_icode == IRRMOVQ ? 0:
    E_icode == IIRMOVQ ? 0 : 0;

    //ALU fun. block
    assign alufun =((E_icode == IOPQ) ? E_ifun : ALUADD);
    
    //Set CC block
    assign set_cc =(((E_icode == IOPQ) & ~(m_stat == SADR | m_stat == SINS | m_stat ==SHLT)) & ~(W_stat == SADR | W_stat == SINS | W_stat == SHLT));
    
    //ALU block
    alu alu(aluA, aluB, alufun, e_valE, new_cc);
    
    //CC block
    cc ccreg(cc, new_cc,set_cc, resetting, clock);
    
    //Cond block
    cond cond_check(E_ifun, cc, e_Cnd);

    //e_valA block
    assign e_valA =E_valA;
    
    //e_dstE block
    assign e_dstE =(((E_icode == IRRMOVQ) & ~e_Cnd) ? RNONE : E_dstE);


    //MEMORY LOGIC

    //Addr. block
    assign mem_addr =
    M_icode == IRMMOVQ ? M_valE :
    M_icode == IPUSHQ ? M_valE :
    M_icode == ICALL ? M_valE :
    M_icode == IMRMOVQ ? M_valE : 
    M_icode == IPOPQ ? M_valA : 
    M_icode == IRET ? M_valA : 0;
    
    //Mem. read block
    assign mem_read =(M_icode == IMRMOVQ | M_icode == IPOPQ | M_icode == IRET);
    
    //Mem. write block
    assign mem_write =(M_icode == IRMMOVQ | M_icode == IPUSHQ | M_icode == ICALL);

    //Data Memory block
    data_memory d(mem_addr,M_valA,mem_read,mem_write,mem_data,dmem_error);

    //Stat block
    assign m_stat =(dmem_error ? SADR : M_stat);


    //WRITEBACK LOGIC
    //In general write-back is implemented with decode stage
    assign w_dstE =W_dstE;
    assign w_valE =W_valE;
    assign w_dstM =W_dstM;
    assign w_valM =W_valM;
    assign Stat =((W_stat == SBUB) ? SAOK : W_stat);
    
    //Stall and Bubble declarations
    assign F_bubble =0;
    assign F_stall =(((E_icode == IMRMOVQ | E_icode == IPOPQ) & (E_dstM == d_srcA | E_dstM == d_srcB)) | (IRET == D_icode | IRET == E_icode | IRET == M_icode));
    assign D_stall =((E_icode == IMRMOVQ | E_icode == IPOPQ) & (E_dstM == d_srcA | E_dstM == d_srcB));
    assign D_bubble =(((E_icode == IJXX) & ~e_Cnd) | (~((E_icode == IMRMOVQ | E_icode ==IPOPQ) & (E_dstM == d_srcA | E_dstM == d_srcB)) & (IRET ==D_icode | IRET == E_icode | IRET == M_icode)));
    assign E_stall =0;
    assign E_bubble =(((E_icode == IJXX) & ~e_Cnd) | ((E_icode == IMRMOVQ | E_icode == IPOPQ) & (E_dstM == d_srcA | E_dstM == d_srcB)));
    assign M_stall =0;
    assign M_bubble =((m_stat == SADR | m_stat == SINS | m_stat == SHLT) | (W_stat == SADR | W_stat == SINS | W_stat == SHLT));
    assign W_stall =(W_stat == SADR | W_stat == SINS | W_stat == SHLT);
    assign W_bubble =0;

    //PIPELINED REGISTERS
    
    //F Register
    pipereg #(64) F_predPC_reg(F_predPC, f_predPC, F_stall, 64'b0, clock);
    
    // D Register
    pipereg #(3) D_stat_reg(D_stat, f_stat, D_stall,   SBUB, clock);
    pipereg #(64) D_pc_reg(D_pc, f_pc, D_stall,   64'b0, clock);
    pipereg2 #(4) D_icode_reg(D_icode, f_icode, D_stall, D_bubble,  INOP, clock);
    pipereg #(4) D_ifun_reg(D_ifun, f_ifun, D_stall, FNONE, clock);
    pipereg #(4) D_rA_reg(D_rA, f_rA, D_stall, RNONE, clock);
    pipereg #(4) D_rB_reg(D_rB, f_rB, D_stall, RNONE, clock);
    pipereg #(64) D_valC_reg(D_valC, f_valC, D_stall, 64'b0, clock);
    pipereg #(64) D_valP_reg(D_valP, f_valP, D_stall, 64'b0, clock);

    // E Register
    pipereg #(3) E_stat_reg(E_stat, D_stat, E_stall,  SBUB, clock);
    pipereg #(64) E_pc_reg(E_pc, D_pc, E_stall,  64'b0, clock);
    pipereg2 #(4) E_icode_reg(E_icode, D_icode, E_stall,E_bubble,  INOP, clock);
    pipereg #(4) E_ifun_reg(E_ifun, D_ifun, E_stall,  FNONE, clock);
    pipereg #(64) E_valC_reg(E_valC, D_valC, E_stall,  64'b0, clock);
    pipereg #(64) E_valA_reg(E_valA, d_valA, E_stall,  64'b0, clock);
    pipereg #(64) E_valB_reg(E_valB, d_valB, E_stall,  64'b0, clock);
    pipereg #(4) E_dstE_reg(E_dstE, d_dstE, E_stall,  RNONE, clock);
    pipereg #(4) E_dstM_reg(E_dstM, d_dstM, E_stall,  RNONE, clock);
    pipereg #(4) E_srcA_reg(E_srcA, d_srcA, E_stall,  RNONE, clock);
    pipereg #(4) E_srcB_reg(E_srcB, d_srcB, E_stall,  RNONE, clock);

    // M Register
    pipereg #(3) M_stat_reg(M_stat, E_stat, M_stall,  SBUB, clock);
    pipereg #(64) M_pc_reg(M_pc, E_pc, M_stall,  64'b0, clock);
    pipereg2 #(4) M_icode_reg(M_icode, E_icode, M_stall,M_bubble,  INOP, clock);
    pipereg #(4) M_ifun_reg(M_ifun, E_ifun, M_stall,  FNONE, clock);
    pipereg #(1) M_Cnd_reg(M_Cnd, e_Cnd, M_stall,  1'b0, clock);
    pipereg #(64) M_valE_reg(M_valE, e_valE, M_stall,  64'b0, clock);
    pipereg #(64) M_valA_reg(M_valA, e_valA, M_stall,  64'b0, clock);
    pipereg #(4) M_dstE_reg(M_dstE, e_dstE, M_stall,  RNONE, clock);
    pipereg #(4) M_dstM_reg(M_dstM, E_dstM, M_stall,  RNONE, clock);

    // W Register
    pipereg #(3) W_stat_reg(W_stat, m_stat, W_stall,  SBUB, clock);
    pipereg #(64) W_pc_reg(W_pc, M_pc, W_stall,  64'b0, clock);
    pipereg2 #(4) W_icode_reg(W_icode, M_icode, W_stall,W_bubble,  INOP, clock);
    pipereg #(64) W_valE_reg(W_valE, M_valE, W_stall,  64'b0, clock);
    pipereg #(64) W_valM_reg(W_valM, m_valM, W_stall,  64'b0, clock);
    pipereg #(4) W_dstE_reg(W_dstE, M_dstE, W_stall,  RNONE, clock);
    pipereg #(4) W_dstM_reg(W_dstM, M_dstM, W_stall,  RNONE, clock);

    //DEBUG STATEMENTS
    always @(posedge clock) begin
         $display("%b", F_predPC);
        end
    
endmodule