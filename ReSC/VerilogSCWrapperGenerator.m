%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright (C) 2016 N. Eamon Gaffney
%%
%% This program is free software; you can resdistribute and/or modify it under
%% the terms of the MIT license, a copy of which should have been included with
%% this program at https://github.com/arminalaghi/scsynth
%%
%% References:
%% W. Qian, X. Li, M. D. Riedel, K. Bazargan and D. J. Lilja, "An Architecture
%% for Fault-Tolerant Computation with Stochastic Logic," in IEEE Transactions
%% on Computers, vol. 60, no. 1, pp. 93-105, Jan. 2011.
%% doi: 10.1109/TC.2010.202
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function VerilogSCWrapperGenerator (coeff, N, m_input, m_coeff, randModule,
                                    ReSCModule, moduleName)

  %Generates a Verilog module that wraps an ReSC unit with conversions
  %from binary to stochastic on the inputs and from stochastic to binary
  %on the outputs.
  
  %Parameters:
  % coeff     : a list of coefficients of the Bernstein polynomial; each
  %             coefficient should fall within the unit interval
  % N         : the length of the stochastic bitstreams, must be a power of 2
  % m_input   : the length in bits of the input, at most log2(N)
  % m_coeff   : the length in bits of the coefficients, at most log2(N)
  % randModule: name of the randomizing Verilog module to be used for
  %             stochastic number generation
  % ReSCModule: name of the ReSC module to wrap
  % moduleName: the name of the verilog module
  
  m = log2(N);
  decimal_coeffs = round(coeff * 2^m_coeff) / (2^m_coeff) * N;
  degree = length(coeff) - 1;
  
	fileName = sprintf('%s.v', moduleName);
  
  fp = fopen(fileName, 'w');
  
  %declare module
  fprintf(fp, 'module %s(\n', moduleName);
	fprintf(fp, '\tinput [%d:0] x_bin,\n', m_input - 1);
  fprintf(fp, '\tinput start,\n');
  fprintf(fp, '\toutput reg done,\n');
  fprintf(fp, '\toutput reg [%d:0] y_bin,\n\n', m - 1);
  
	fprintf(fp, '\tinput clk,\n');
	fprintf(fp, '\tinput reset\n');
  fprintf(fp, ');\n\n');

  if (m_input < m)
    fprintf(fp, '\twire [%d:0] x_bin_shifted;\n', m - 1);
    fprintf(fp, '\tassign x_bin_shifted = x_bin << %d;\n\n', m - m_input);
  end
  
  %define the constant coefficients
  for i=0:degree
    fprintf(fp, "\treg [%d:0] c%d_bin = %d\'d%d;\n", m - 1, i, m,
            decimal_coeffs(i+1));
  end

  %declare internal wires
	fprintf(fp, '\n\twire [%d:0] x_stoch;\n', degree - 1);
	fprintf(fp, '\twire [%d:0] z_stoch;\n', degree);
	fprintf(fp, '\twire y_stoch;\n');
	fprintf(fp, '\twire init;\n');
	fprintf(fp, '\twire running;\n\n');

  %binary to stochastic conversion for the x values
  for i=0:degree - 1
    fprintf(fp, '\twire [%d:0] randx%d;\n', m - 1, i);
    fprintf(fp, '\t%s rand_gen_x_%d (\n', randModule, i);
		fprintf(fp, "\t\t.seed (%d'd%d),\n", m, round(N*i/(degree*2+1)));
		fprintf(fp, '\t\t.data (randx%d),\n', i);
		fprintf(fp, '\t\t.enable (running),\n');
		fprintf(fp, '\t\t.restart (init),\n');
		fprintf(fp, '\t\t.clk (clk),\n');
		fprintf(fp, '\t\t.reset (reset)\n');0
		fprintf(fp, '\t);\n');
    if (m_input < m)
      fprintf(fp, '\tassign x_stoch[%d] = randx%d < x_bin_shifted;\n\n', i, i);
    else
      fprintf(fp, '\tassign x_stoch[%d] = randx%d < x_bin;\n\n',  i, i);
    end
  end
  
  %binary to stochastic conversion for the coefficients
  for i=0:degree
    fprintf(fp, '\twire [%d:0] randz%d;\n', m - 1, i);
    fprintf(fp, '\t%s rand_gen_z_%d (\n', randModule, i);
		fprintf(fp, "\t\t.seed (%d'd%d),\n", m, round(N*(i+degree)/(degree*2+1)));
		fprintf(fp, '\t\t.data (randz%d),\n', i);
		fprintf(fp, '\t\t.enable (running),\n');
		fprintf(fp, '\t\t.restart (init),\n');
		fprintf(fp, '\t\t.clk (clk),\n');
		fprintf(fp, '\t\t.reset (reset)\n');
		fprintf(fp, '\t);\n');
    fprintf(fp, '\tassign z_stoch[%d] = randz%d < c%d_bin;\n\n',  i, i, i);
  end

  %initialize the core ReSC module
	fprintf(fp, '\t%s ReSC (\n', ReSCModule);
	fprintf(fp, '\t\t.x (x_stoch),\n');
	fprintf(fp, '\t\t.z (z_stoch),\n');
	fprintf(fp, '\t\t.y (y_stoch)\n');
	fprintf(fp, '\t);\n\n');

  %create finite state machine for handling  stochastic to binary conversion
  %and handshaking with the client
	fprintf(fp, '\treg [%d:0] count;\n', m - 1');
	fprintf(fp, '\twire [%d:0] neg_one;\n', m - 1);
	fprintf(fp, '\tassign neg_one = -1;\n\n');

	fprintf(fp, '\treg [1:0] cs;\n');
	fprintf(fp, '\treg [1:0] ns;\n');
	fprintf(fp, '\tassign init = cs == 1;\n');
	fprintf(fp, '\tassign running = cs == 2;\n\n');

	fprintf(fp, '\talways @(posedge clk or posedge reset) begin\n');
	fprintf(fp, '\t\tif (reset) cs <= 0;\n');
	fprintf(fp, '\t\telse begin\n');
  fprintf(fp, '\t\t\tcs <= ns;\n');
	fprintf(fp, '\t\t\tif (running) begin\n');
	fprintf(fp, '\t\t\t\tif (count == neg_one) done <= 1;\n');
	fprintf(fp, '\t\t\t\tcount <= count + 1;\n');
	fprintf(fp, '\t\t\t\ty_bin <= y_bin + y_stoch;\n');
	fprintf(fp, '\t\t\tend\n');
	fprintf(fp, '\t\tend\n');
	fprintf(fp, '\tend\n\n');

	fprintf(fp, '\talways @(*) begin\n');
	fprintf(fp, '\t\tcase (cs)\n');
	fprintf(fp, '\t\t\t0: if (start) ns = 1; else ns = 0;\n');
	fprintf(fp, '\t\t\t1: if (start) ns = 1; else ns = 2;\n');
	fprintf(fp, '\t\t\t2: if (done) ns = 0; else ns = 2;\n');
	fprintf(fp, '\t\t\tdefault ns = 0;\n');
	fprintf(fp, '\t\tendcase\n');
	fprintf(fp, '\tend\n\n');

	fprintf(fp, '\talways @(posedge init) begin\n');
	fprintf(fp, '\t\tcount <= 0;\n');
	fprintf(fp, '\t\ty_bin <= 0;\n');
	fprintf(fp, '\t\tdone <= 0;\n');
	fprintf(fp, '\tend\n');
  fprintf(fp, 'endmodule\n');

  fclose(fp);
end
