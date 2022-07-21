% load patients.mat
% T = table(LastName,Age,Weight,Smoker);
% T(1:5,:)
% filename = 'patientdata.xlsx';
% writetable(T,filename,'Sheet',1,'Range','D1')
% writetable(T,filename,'Sheet','MyNewSheet','WriteVariableNames',false);

% A = magic(5)
% C = {'Time', 'Temp'; 12 98; 13 'x'; 14 97}
% filename = 'testdata.xlsx';
% writematrix(A,filename,'Sheet',1,'Range','E1:I5')
% writecell(C,filename,'Sheet','Temperatures','Range','B2');

clear;
clc;

mpc = pglib_opf_case14_ieee;

filename = 'case.xlsx';

bus_headers = {'index', 'name', 'slack', 'vn_kv', 'v_pu_min', 'v_pu_max'};
writecell(bus_headers,filename,'Sheet','Bus');

bus_i = mpc.bus(:,1) - 1;
bus_name = "bus" + bus_i;
bus_slack = zeros(height(mpc.bus), 1);
bus_slack(1)=1;
bus_data = [bus_i bus_name bus_slack mpc.bus(:,[10 13 12])];

%	1bus_i	2type	3Pd	4Qd	5Gs	6Bs	7area	8Vm	9Va	10baseKV	11zone	12Vmax	13Vmin
writematrix(bus_data,filename,'Sheet','Bus','Range','A2');







