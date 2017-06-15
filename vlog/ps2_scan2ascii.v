////////////////////////////////////////////////////////////////////////////////
//
// MIT License
//
// Copyright (c) 2017 Smartfox Data Solutions Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in 
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////

module ps2_scan2ascii(clk, ps2_code_new, ps2_code, ascii_code_new, ascii_code);

  input clk;
  input ps2_code_new;
  input [7:0] ps2_code;
  output ascii_code_new;
  output [7:0] ascii_code;

  parameter
  ST_MAKE=0,
  ST_BREAK=1;

  reg state=0, next_state=0;
 
  reg ps2_code_new_q=0;
  reg [7:0] ps2_code_q=0;
  reg capstoggle=0, capslock=0;
  reg shift=0;
  reg ascii_code_new=0;
  reg [7:0] ascii_code=0;
  reg [15:0] make_code=0;
  reg ps2_ready=0;
  reg ascii_ready=0;

  // input
  always @(posedge clk) begin
    ps2_code_new_q <= ps2_code_new;
  end
  
  always @(*)
    ps2_ready = ps2_code_new==1 && ps2_code_new_q==0;

  // state machine
  always @(posedge clk) begin
    state <= next_state;
  end

  always @(*) begin
    next_state = state;
    case (state)
      ST_MAKE: begin // get make code
        if (ps2_ready) begin
          if (ps2_code == 8'hF0)
            next_state = ST_BREAK;
          else
            next_state = ST_MAKE;
        end
      end      
      ST_BREAK: begin // get break code
        if (ps2_ready) begin
          if (ps2_code == 8'hE0)
            next_state = ST_BREAK;
          else begin
            next_state = ST_MAKE;
          end
        end
      end
      default: next_state = ST_MAKE;
    endcase
  end
  
  // handle shift and capslock
  always @(posedge clk) begin
    if (state == ST_MAKE && ps2_ready==1) begin
      if (ps2_code == 8'h58) begin
        if (capstoggle==0) begin          
          capstoggle <= 1;
        end
      end
      if (ps2_code == 8'h12 || ps2_code == 8'h59)
        shift <= ~shift;
    end
    else if (state == ST_BREAK && ps2_ready==1) begin
      if (ps2_code == 8'h58) begin
        if (capstoggle==1) begin
          capslock <= ~capslock;
        end
        capstoggle <= 0;
      end
      if (ps2_code == 8'h12 || ps2_code == 8'h59)
        shift <= 0;
    end
  end
  
  // get make_code
  always @(posedge clk) begin
    if (ps2_ready && state == ST_MAKE) begin
      case (ps2_code)
        8'hF0,8'h58,8'h12,8'h59: make_code <= make_code;
        8'hE0: make_code <= {ps2_code, make_code[7:0]};
        default: make_code <= {make_code[15:8], ps2_code};
      endcase
    end
    else if (ascii_ready && state == ST_BREAK)
      make_code <= 16'h0;
  end

  always @(*)
    ascii_ready = state==ST_BREAK && ps2_ready==1 && ascii_code!=0;
  
  // outputs
  always @(posedge clk) begin
    ascii_code_new <= ascii_ready;
    // arrow keys
    if (make_code[15:8]==8'hE0) begin
      ascii_code <= {1'b1,make_code[6:0]};
    end
    // some special keys
    else if (make_code[7:0]==8'h76)
      ascii_code <= 8'h1B; //esc
    else if (make_code[7:0]==8'h66)
      ascii_code <= 8'h08; //bkspc
    else if (make_code[7:0]==8'h5A)
      ascii_code <= 8'h0D; //ret
    else if (make_code[7:0]==8'h29)
      ascii_code <= 8'h20; //space
    else begin
      // chars that depend on capslock and shift
      if (shift==0) begin //lower case
        casex ({capslock,make_code[7:0]})
          9'hx_45: ascii_code <= 8'h30; //0
          9'hx_16: ascii_code <= 8'h31; //1
          9'hx_1E: ascii_code <= 8'h32; //2
          9'hx_26: ascii_code <= 8'h33; //3
          9'hx_25: ascii_code <= 8'h34; //4
          9'hx_2E: ascii_code <= 8'h35; //5
          9'hx_36: ascii_code <= 8'h36; //6
          9'hx_3D: ascii_code <= 8'h37; //7
          9'hx_3E: ascii_code <= 8'h38; //8
          9'hx_46: ascii_code <= 8'h39; //9
          9'hx_52: ascii_code <= 8'h27; //'
          9'hx_41: ascii_code <= 8'h2C; //,
          9'hx_4E: ascii_code <= 8'h2D; //-
          9'hx_49: ascii_code <= 8'h2E; //.
          9'hx_4A: ascii_code <= 8'h2F; ///
          9'hx_4C: ascii_code <= 8'h3B; //;
          9'hx_55: ascii_code <= 8'h3D; //=
          9'hx_54: ascii_code <= 8'h5B; //[
          9'hx_5D: ascii_code <= 8'h5C; //\
          9'hx_5B: ascii_code <= 8'h5D; //]
          9'hx_0E: ascii_code <= 8'h60; //`       
          9'h0_1C: ascii_code <= 8'h61; //a
          9'h0_32: ascii_code <= 8'h62; //b
          9'h0_21: ascii_code <= 8'h63; //c
          9'h0_23: ascii_code <= 8'h64; //d
          9'h0_24: ascii_code <= 8'h65; //e
          9'h0_2B: ascii_code <= 8'h66; //f
          9'h0_34: ascii_code <= 8'h67; //g
          9'h0_33: ascii_code <= 8'h68; //h
          9'h0_43: ascii_code <= 8'h69; //i
          9'h0_3B: ascii_code <= 8'h6A; //j
          9'h0_42: ascii_code <= 8'h6B; //k
          9'h0_4B: ascii_code <= 8'h6C; //l
          9'h0_3A: ascii_code <= 8'h6D; //m
          9'h0_31: ascii_code <= 8'h6E; //n
          9'h0_44: ascii_code <= 8'h6F; //o
          9'h0_4D: ascii_code <= 8'h70; //p
          9'h0_15: ascii_code <= 8'h71; //q
          9'h0_2D: ascii_code <= 8'h72; //r
          9'h0_1B: ascii_code <= 8'h73; //s
          9'h0_2C: ascii_code <= 8'h74; //t
          9'h0_3C: ascii_code <= 8'h75; //u
          9'h0_2A: ascii_code <= 8'h76; //v
          9'h0_1D: ascii_code <= 8'h77; //w
          9'h0_22: ascii_code <= 8'h78; //x
          9'h0_35: ascii_code <= 8'h79; //y
          9'h0_1A: ascii_code <= 8'h7A; //z
          9'h1_1C: ascii_code <= 8'h41; //A
          9'h1_32: ascii_code <= 8'h42; //B
          9'h1_21: ascii_code <= 8'h43; //C
          9'h1_23: ascii_code <= 8'h44; //D
          9'h1_24: ascii_code <= 8'h45; //E
          9'h1_2B: ascii_code <= 8'h46; //F
          9'h1_34: ascii_code <= 8'h47; //G
          9'h1_33: ascii_code <= 8'h48; //H
          9'h1_43: ascii_code <= 8'h49; //I
          9'h1_3B: ascii_code <= 8'h4A; //J
          9'h1_42: ascii_code <= 8'h4B; //K
          9'h1_4B: ascii_code <= 8'h4C; //L
          9'h1_3A: ascii_code <= 8'h4D; //M
          9'h1_31: ascii_code <= 8'h4E; //N
          9'h1_44: ascii_code <= 8'h4F; //O
          9'h1_4D: ascii_code <= 8'h50; //P
          9'h1_15: ascii_code <= 8'h51; //Q
          9'h1_2D: ascii_code <= 8'h52; //R
          9'h1_1B: ascii_code <= 8'h53; //S
          9'h1_2C: ascii_code <= 8'h54; //T
          9'h1_3C: ascii_code <= 8'h55; //U
          9'h1_2A: ascii_code <= 8'h56; //V
          9'h1_1D: ascii_code <= 8'h57; //W
          9'h1_22: ascii_code <= 8'h58; //X
          9'h1_35: ascii_code <= 8'h59; //Y
          9'h1_1A: ascii_code <= 8'h5A; //Z
          default: ascii_code <= 8'h00;
        endcase
      end
      else if (shift == 1) begin //uppercase
        casex ({capslock,make_code[7:0]})
          9'hx_16: ascii_code <= 8'h21; //!
          9'hx_52: ascii_code <= 8'h22; //"
          9'hx_26: ascii_code <= 8'h23; //#
          9'hx_25: ascii_code <= 8'h24; //$
          9'hx_2E: ascii_code <= 8'h25; //%
          9'hx_3D: ascii_code <= 8'h26; //&              
          9'hx_46: ascii_code <= 8'h28; //(
          9'hx_45: ascii_code <= 8'h29; //)
          9'hx_3E: ascii_code <= 8'h2A; //*
          9'hx_55: ascii_code <= 8'h2B; //+
          9'hx_4C: ascii_code <= 8'h3A; //:
          9'hx_41: ascii_code <= 8'h3C; //<
          9'hx_49: ascii_code <= 8'h3E; //>
          9'hx_4A: ascii_code <= 8'h3F; //?
          9'hx_1E: ascii_code <= 8'h40; //@
          9'hx_36: ascii_code <= 8'h5E; //^
          9'hx_4E: ascii_code <= 8'h5F; //_
          9'hx_54: ascii_code <= 8'h7B; //{
          9'hx_5D: ascii_code <= 8'h7C; //|
          9'hx_5B: ascii_code <= 8'h7D; //}
          9'hx_0E: ascii_code <= 8'h7E; //~
          9'h1_1C: ascii_code <= 8'h61; //a
          9'h1_32: ascii_code <= 8'h62; //b  
          9'h1_21: ascii_code <= 8'h63; //c
          9'h1_23: ascii_code <= 8'h64; //d
          9'h1_24: ascii_code <= 8'h65; //e
          9'h1_2B: ascii_code <= 8'h66; //f
          9'h1_34: ascii_code <= 8'h67; //g
          9'h1_33: ascii_code <= 8'h68; //h
          9'h1_43: ascii_code <= 8'h69; //i
          9'h1_3B: ascii_code <= 8'h6A; //j
          9'h1_42: ascii_code <= 8'h6B; //k
          9'h1_4B: ascii_code <= 8'h6C; //l
          9'h1_3A: ascii_code <= 8'h6D; //m
          9'h1_31: ascii_code <= 8'h6E; //n
          9'h1_44: ascii_code <= 8'h6F; //o
          9'h1_4D: ascii_code <= 8'h70; //p
          9'h1_15: ascii_code <= 8'h71; //q
          9'h1_2D: ascii_code <= 8'h72; //r
          9'h1_1B: ascii_code <= 8'h73; //s
          9'h1_2C: ascii_code <= 8'h74; //t
          9'h1_3C: ascii_code <= 8'h75; //u
          9'h1_2A: ascii_code <= 8'h76; //v
          9'h1_1D: ascii_code <= 8'h77; //w
          9'h1_22: ascii_code <= 8'h78; //x
          9'h1_35: ascii_code <= 8'h79; //y
          9'h1_1A: ascii_code <= 8'h7A; //z
          9'h0_1C: ascii_code <= 8'h41; //A
          9'h0_32: ascii_code <= 8'h42; //B
          9'h0_21: ascii_code <= 8'h43; //C
          9'h0_23: ascii_code <= 8'h44; //D
          9'h0_24: ascii_code <= 8'h45; //E
          9'h0_2B: ascii_code <= 8'h46; //F
          9'h0_34: ascii_code <= 8'h47; //G
          9'h0_33: ascii_code <= 8'h48; //H
          9'h0_43: ascii_code <= 8'h49; //I
          9'h0_3B: ascii_code <= 8'h4A; //J
          9'h0_42: ascii_code <= 8'h4B; //K
          9'h0_4B: ascii_code <= 8'h4C; //L
          9'h0_3A: ascii_code <= 8'h4D; //M
          9'h0_31: ascii_code <= 8'h4E; //N
          9'h0_44: ascii_code <= 8'h4F; //O
          9'h0_4D: ascii_code <= 8'h50; //P
          9'h0_15: ascii_code <= 8'h51; //Q
          9'h0_2D: ascii_code <= 8'h52; //R
          9'h0_1B: ascii_code <= 8'h53; //S
          9'h0_2C: ascii_code <= 8'h54; //T
          9'h0_3C: ascii_code <= 8'h55; //U
          9'h0_2A: ascii_code <= 8'h56; //V
          9'h0_1D: ascii_code <= 8'h57; //W
          9'h0_22: ascii_code <= 8'h58; //X
          9'h0_35: ascii_code <= 8'h59; //Y
          9'h0_1A: ascii_code <= 8'h5A; //Z
          default: ascii_code <= 8'h00;
        endcase
      end
    end
  end
  
endmodule
