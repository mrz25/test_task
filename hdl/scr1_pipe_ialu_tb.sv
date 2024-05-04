`include "scr1_riscv_isa_decoding.svh"

module scr1_pipe_ialu_tb ();

    localparam WATCHDOG_TIMER = 10000;
    localparam logic [`SCR1_XLEN-1:0] max_val = 2**`SCR1_XLEN - 1;

    covergroup toggle_cg with function sample(input bit eachbit_op1, input bit eachbit_op2); 
        option.per_instance = 0;
        type_option.merge_instances = 1;
        //cp for 1 operand
        coverpoint eachbit_op1 {
            bins roam_0 = ( 1 => 0 => 1 );
            bins roam_1 = ( 0 => 1 => 0 );
        }
        //cp for 2 operand
        coverpoint eachbit_op2 {
            bins roam_0 = ( 1 => 0 => 1 );
            bins roam_1 = ( 0 => 1 => 0 );
        }
        cp_command : coverpoint data.exu2ialu_cmd_i 
        {
            bins comm_add = { SCR1_IALU_CMD_ADD };
            bins comm_sub = { SCR1_IALU_CMD_SUB };
        }
        op1_X_op2_X_comm : cross cp_command, eachbit_op1, eachbit_op2 ;
    endgroup : toggle_cg

    class ialu_data;
        localparam NUM_OF_CG = 33;

        //operation
        rand logic [`SCR1_XLEN-1:0]          exu2ialu_main_op1_i;
        rand logic [`SCR1_XLEN-1:0]          exu2ialu_main_op2_i;
        rand type_scr1_ialu_cmd_sel_e        exu2ialu_cmd_i;
        
        //addr
        rand logic [`SCR1_XLEN-1:0]          exu2ialu_addr_op1_i;
        rand logic [`SCR1_XLEN-1:0]          exu2ialu_addr_op2_i;
        
        //cg for stray 0 or 1
        toggle_cg t_cg[32];

        //general cg
        covergroup cg;
            option.at_least = 25;

            // total coverpoint , 4 equal intervals
            cp_operand1 : coverpoint exu2ialu_main_op1_i
            {
                bins a0[4] =        {[0 : max_val]};
            }
            
            //directed cp
            cp_op1_dir : coverpoint exu2ialu_main_op1_i 
            {
                bins a1    =        {max_val};
                bins a2    =        {32'd1};
                bins a3    =        {32'd0};
            }

            // total coverpoint , 4 equal intervals
            cp_operand2 : coverpoint exu2ialu_main_op2_i
            {
                bins a0[4] =        {[0 : max_val]};
            }

            //directed cp
            cp_op2_dir : coverpoint exu2ialu_main_op2_i 
            {
                bins a1    =        {max_val};
                bins a2    =        {32'd1};
                bins a3    =        {32'd0};
            }

            cp_command : coverpoint exu2ialu_cmd_i 
            {
                bins comm_add = { SCR1_IALU_CMD_ADD };
                bins comm_sub = { SCR1_IALU_CMD_SUB };
            }
            op1_X_op2_X_comm : cross cp_command, cp_operand1, cp_operand2 ;
            dir_op1_X_op2_X_comm : cross cp_command, cp_op1_dir, cp_op2_dir ;

            // total coverpoint , 4 equal intervals
            cp_addr_op1 : coverpoint exu2ialu_addr_op1_i 
            {
                bins a0[4] =        {[0 : max_val]};
            }

            // total coverpoint , 4 equal intervals
            cp_addr_op2 : coverpoint exu2ialu_addr_op2_i
            {
                bins a0[4] =        {[0 : max_val]};
            }
            addr1_X_addr2 : cross cp_addr_op1, cp_addr_op2 ;
        endgroup : cg

        function new ();
            begin
                cg = new();
                foreach(t_cg[ii]) begin
                    t_cg[ii] = new();
                end
            end
        endfunction : new

        function void sample ();
            begin
                cg.sample();
                foreach(t_cg[ii]) begin
                    t_cg[ii].sample(exu2ialu_main_op1_i[ii], exu2ialu_main_op2_i[ii]);
                end 
            end
        endfunction : sample

        function real get_coverage(); 
            real sum;
            begin
                sum = cg.get_inst_coverage();
                foreach(t_cg[ii]) begin 
                    sum = sum + t_cg[ii].get_inst_coverage();
                end
                return sum / NUM_OF_CG;
            end
        endfunction : get_coverage

        function void inverse_comm ();
            if (exu2ialu_cmd_i == SCR1_IALU_CMD_ADD) begin
                exu2ialu_cmd_i = SCR1_IALU_CMD_SUB;
            end else begin 
                exu2ialu_cmd_i = SCR1_IALU_CMD_ADD;
            end
        endfunction : inverse_comm 

        //only these operations are tested
        constraint correct_operation {
            exu2ialu_cmd_i == SCR1_IALU_CMD_ADD || 
            exu2ialu_cmd_i == SCR1_IALU_CMD_SUB ;
        }
    endclass : ialu_data

    //operation
    logic [`SCR1_XLEN-1:0]          exu2ialu_main_op1_i;
    logic [`SCR1_XLEN-1:0]          exu2ialu_main_op2_i;
    type_scr1_ialu_cmd_sel_e        exu2ialu_cmd_i;

    logic [`SCR1_XLEN-1:0]          ialu2exu_main_res_o;
    logic                           ialu2exu_cmp_res_o;
        
    //addr
    logic [`SCR1_XLEN-1:0]          exu2ialu_addr_op1_i;
    logic [`SCR1_XLEN-1:0]          exu2ialu_addr_op2_i;

    logic [`SCR1_XLEN-1:0]          ialu2exu_addr_res_o;

    int err_cnt;
    ialu_data data = new();

    function void inst_pins();
        begin 
            exu2ialu_main_op1_i = data.exu2ialu_main_op1_i;
            exu2ialu_main_op2_i = data.exu2ialu_main_op2_i;
            exu2ialu_cmd_i      = data.exu2ialu_cmd_i;
            exu2ialu_addr_op1_i = data.exu2ialu_addr_op1_i;
            exu2ialu_addr_op2_i = data.exu2ialu_addr_op2_i;
        end
    endfunction : inst_pins

    function void display_error_operation(input string str);
        $error("Incorrect %s operation.", str);
    endfunction : display_error_operation

    function void check_outputs();
        logic [`SCR1_XLEN:0] ref_res;
        logic ref_compare_res;
        logic [`SCR1_XLEN-1:0] ref_addr;
        string error_op_str;
        begin 
            //check operation result
            case (exu2ialu_cmd_i)
                SCR1_IALU_CMD_ADD: begin
                    ref_res = {1'b0, exu2ialu_main_op1_i} + {1'b0, exu2ialu_main_op2_i};
                    error_op_str = "ADD";
                end
                SCR1_IALU_CMD_SUB: begin
                    ref_res = {1'b0, exu2ialu_main_op1_i} - {1'b0, exu2ialu_main_op2_i};
                    error_op_str = "SUB";
                end
            endcase
            if (ref_res[`SCR1_XLEN-1:0] !== ialu2exu_main_res_o) begin
                display_error_operation(error_op_str);
                $display("Reference_result = %h\nDUT_result = %h\n", ref_res[`SCR1_XLEN-1:0], ialu2exu_main_res_o);
                err_cnt++;
            end
            
            //check compare result
            case (exu2ialu_cmd_i)
                SCR1_IALU_CMD_ADD,
                SCR1_IALU_CMD_SUB : begin
                    ref_compare_res = 1'b0;
                end
            endcase
            if (ref_compare_res !== ialu2exu_cmp_res_o) begin
                display_error_operation(error_op_str);
                $display("Reference_compare = %h\nDUT_compare = %h\n", ref_compare_res, ialu2exu_cmp_res_o);
                err_cnt++;
            end

            //check addr
            ref_addr = exu2ialu_addr_op1_i + exu2ialu_addr_op2_i;
            if (ref_addr !== ialu2exu_addr_res_o) begin
                $error("Incorrect OUT address.");
                $display("Reference_addr = %h\nDUT_addr = %h\n", ref_addr, ialu2exu_addr_res_o);
                err_cnt++;
            end
            data.sample();
        end
    endfunction : check_outputs
    
    //specific value testing
    task directed_test();
        static int dir_val [3] = {32'd0, 32'd1, max_val};
        begin 
            repeat(25) begin
                for (int i = 0; i < 3; i++) begin
                    for (int j = 0; j < 3; j++) begin
                        if (data.randomize()) begin
                            data.exu2ialu_main_op1_i = dir_val[i];
                            data.exu2ialu_main_op2_i = dir_val[j];
                            inst_pins();
                            #1;
                            check_outputs();

                            data.inverse_comm();
                            inst_pins();
                            #1;
                            check_outputs();
                        end        
                    end
                end
            end
        end
    endtask : directed_test

    function automatic logic[31:0] get_roam_data(input bit X, input int iter);
        logic [31:0] one = '1;
        logic [31:0] zero = '0;
        begin
            if (X) begin
                zero[iter] = X;
                return zero;
            end else begin
                one[iter] = X;
                return one;              
            end
        end
    endfunction : get_roam_data

    //stray 0 or 1
    task test_stray_X(input bit X);
        begin
            for (int i = 0; i < `SCR1_XLEN; i++) begin
                for (int j = 0; j < `SCR1_XLEN; j++) begin
                    if (data.randomize()) begin
                        data.exu2ialu_main_op1_i = get_roam_data(X, i);
                        data.exu2ialu_main_op2_i = get_roam_data(X, j);
                        inst_pins();
                        #1;
                        check_outputs();

                        data.inverse_comm();
                        inst_pins();
                        #1;
                        check_outputs();
                    end      
                end
            end
        end
    endtask : test_stray_X

    task test_rand();
        while(data.get_coverage() < 100) begin
            if (data.randomize()) begin
                inst_pins();
                #1;
                check_outputs();
            end
        end
    endtask : test_rand

    initial begin : main
        directed_test();
        test_stray_X(1'b1);
        test_stray_X(1'b0);
        test_rand();
        $display("===========================");
        $display("TOTAL ERRORS %d", err_cnt);
        $display("Coverage = %0.2f %%", data.get_coverage());
        $display("===========================");
        $finish(1);
    end

    initial begin : wd
        #WATCHDOG_TIMER;
        $finish(-1);
    end

    scr1_pipe_ialu DUT (
        `ifdef SCR1_RVM_EXT
            // Common
            .clk                   (),
            .rst_n                 (),
            .exu2ialu_rvm_cmd_vd_i (),
            .ialu2exu_rvm_res_rdy_o(),
        `endif
        // Main adder
        .exu2ialu_main_op1_i   (exu2ialu_main_op1_i),
        .exu2ialu_main_op2_i   (exu2ialu_main_op2_i),
        .exu2ialu_cmd_i        (exu2ialu_cmd_i),
        .ialu2exu_main_res_o   (ialu2exu_main_res_o),
        .ialu2exu_cmp_res_o    (ialu2exu_cmp_res_o),
        
        //Address adder
        .exu2ialu_addr_op1_i   (exu2ialu_addr_op1_i),
        .exu2ialu_addr_op2_i   (exu2ialu_addr_op2_i),
        .ialu2exu_addr_res_o   (ialu2exu_addr_res_o)
    );

endmodule : scr1_pipe_ialu_tb