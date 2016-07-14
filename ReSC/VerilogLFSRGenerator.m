%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright (C) 2016 Armin Alaghi and N. Eamon Gaffney
%%
%% This program is free software; you can resdistribute and/or modify it under
%% the terms of the MIT license, a copy of which should have been included with
%% this program at https://github.com/arminalaghi/scsynth
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function VerilogLFSRGenerator (dataLen, taps, addZero, moduleName)


    %generates an LFSR Verilog file
    %Parameters:
    % dataLen   : the length of the LFSR in bits
    % taps      : the location of XORs obtained from http://www.newwaveinstrumen
    %             ts.com/resources/articles/m_sequence_linear_feedback_shift_reg
    %             ister_lfsr.htm taps also available in the "taps" folder
    % addZero   : if 0, produces a normal LFSR which does not have the
    %             all-zero state, if 1, artificially adds an all-zero state
    %             (useful in SC)
    % moduleName: the name of the verilog module

	fileName = sprintf('%s.v', moduleName);
  
  fp = fopen(fileName, 'w');

	fprintf(fp, 'module %s(\n', moduleName);

	fprintf(fp, '\tinput [%d:0] seed,\n', dataLen-1);
	fprintf(fp, '\toutput [%d:0] data,\n', dataLen-1);
  fprintf(fp, '\tinput enable,\n');
  fprintf(fp, '\tinput restart,\n\n');
  fprintf(fp, '\tinput reset,\n');
  fprintf(fp, '\tinput clk\n');
  fprintf(fp, ');\n');
  
	fprintf(fp, '\n\treg [%d:0] shift_reg;\n\twire shift_in;\n', dataLen-1);
	fprintf(fp, '\n\talways @(posedge clk or posedge reset) begin\n');
	fprintf(fp, '\t\tif (reset) shift_reg <= seed;\n');
  fprintf(fp, '\t\telse if (restart) shift_reg <= seed;\n');
	fprintf(fp, '\t\telse if (enable) shift_reg <= {shift_reg[%d:0], shift_in};', dataLen-2);
  fprintf(fp, '\n\tend\n\n');

	fprintf(fp, '\n\twire xor_out;\n\tassign xor_out = shift_reg[%d]', taps(1)-1);
	for i=2:length(taps)
		fprintf(fp, ' ^ shift_reg[%d]', taps(i)-1);
	end
	fprintf(fp, ';\n');

	if(addZero)
		fprintf(fp, '\n\twire zero_detector;\n\tassign zero_detector = ~(|(shift_reg[%d:0]));', dataLen-2);
		fprintf(fp, '\n\tassign shift_in = xor_out ^ zero_detector;\n');
	else
		fprintf(fp, '\n\tassign shift_in = xor_out;\n');
	end
		fprintf(fp, '\n\n\tassign data = shift_reg;\nendmodule\n');


	%fflush(fp);
	fclose(fp);
end
